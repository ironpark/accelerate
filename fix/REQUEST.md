# ironpark/accelerate 바인딩 전수 검증 및 수정

## 대상

- 저장소: https://github.com/ironpark/accelerate (내가 만든 Zig 바인딩)
- 규모: `pub fn` 475개, `test` 블록 18개. **사실상 미검증 상태다.**

## 확정된 결함 (이 작업의 출발점)

`src/vdsp/vecop.zig` 의 `vsub`:

```zig
/// Vector subtract.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] - B[n];        // ← 거짓말
pub fn vsub(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsub(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),   // 실제로는 b - a
```

Apple 헤더가 이 함수의 첫 두 인자에 대해 명시적으로 경고한다:

```c
extern void vDSP_vsub(
    const float *__B,  // Caution:  A and B are swapped!
    vDSP_Stride  __IB,
    const float *__A,  // Caution:  A and B are swapped!
    ...
```

즉 `vsub(a, b, out)` 은 주석과 반대로 `b - a` 를 계산한다. 실제 프로덕션 코드
(ultrasync 의 lag scorer 벡터화)에서 이 때문에 결과가 틀렸고, 디버깅으로 발견했다.

## 왜 전수 검증이 필요한가 — 단순 오타가 아니다

헤더에서 `swapped` 경고가 붙은 함수는 아래가 전부다. 바인딩의 대응을 대조하면:

| vDSP 함수                               | 바인딩 위치  | 보상했나                |
| --------------------------------------- | ------------ | ----------------------- |
| `vDSP_vdiv` / `vDSP_vdivD`              | `vecop.zig`  | ✅ 인자를 뒤집어 넘김   |
| `vDSP_vdivi`                            | `vecop.zig`  | ✅                      |
| `vDSP_zvdiv` / `vDSP_zvdivD`            | `zvecop.zig` | ✅                      |
| **`vDSP_vsub` / `vDSP_vsubD`**          | `vecop.zig`  | ❌ **누락 — 확정 버그** |
| `vDSP_vswapD`                           | `util.zig`   | ❓ 미확인               |
| `vDSP_wienerD`                          | `util.zig`   | ❓ 미확인               |
| `vDSP_fft2d_ziptD` / `vDSP_fft2d_zoptD` | `fft.zig`    | ❓ 미확인               |

**저자는 이 함정을 알고 있었고, 세 곳은 처리했는데 한 곳을 빠뜨렸다.**
같은 종류의 "알지만 새어나간" 오류가 다른 위험군에도 있다고 가정하고 접근하라.

## Ground truth 는 이 순서로 신뢰하라

1. **로컬 Apple 헤더가 1차 사양이다.** 인자 순서와 수식이 주석으로 적혀 있다:
   - vDSP: `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/Versions/A/Headers/vDSP.h` (10,377줄)
   - 같은 디렉터리에 `vForce.h`, vImage 는 `.../vImage.framework/Headers/`
2. **실행 결과가 최종 심판이다.** 헤더 주석조차 애매하면 값을 넣고 돌려서 확인하라.
   예: `A=[1,2,3]`, `B=[10,20,30]` 을 넣어 `[9,18,27]`(B−A)인지 `[-9,-18,-27]`(A−B)인지 본다.
   문서 해석 논쟁이 필요 없는 방법이므로 **적극적으로 써라.**
3. Apple 온라인 문서는 보조. 헤더와 충돌하면 헤더가 이긴다.

**추측으로 판정하지 마라.** "이름을 보니 이럴 것이다"는 이 작업에서 금지다.
실제로 돌려본 결과 또는 헤더의 명시적 문구만 근거로 인정한다.

## 함수 하나당 해야 할 일 (475개 전부)

각 `pub fn` 에 대해 세 가지를 판정하고 조치하라:

1. **주석이 실제 동작을 정확히 기술하는가** — 수식, 인자 의미, 길이/스트라이드 규약,
   in-place 허용 여부, 출력 버퍼 크기 요구사항.
2. **시그니처가 타당한가** — 인자 순서/이름이 이름값에 부합하는가.
   `assert` 로 길이를 검증해야 하는데 안 하고 있지 않은가.
   (`a.len` 을 넘기는데 `out.len` 이 더 짧을 수 있는 경우 등 — 이미 일부 함수에만
   `std.debug.assert` 가 있고 일관되지 않다.)
3. **테스트가 있는가** — 없으면 만든다. 이것이 회귀를 막는 유일한 산출물이다.

## 수정 정책: 주석을 고칠까 함수를 고칠까

**원칙: Zig 함수는 이름과 시그니처가 약속하는 대로 동작해야 하고, 주석은 그것을 기술해야 한다.**
Apple 의 인자 순서 기벽은 바인딩이 흡수해서 삼키는 것이 이 라이브러리의 존재 이유다.

- `vsub` 는 **함수를 고쳐라** — `vsub(a, b, out)` 이 `a - b` 를 주도록 내부 호출을 뒤집는다.
  근거: 같은 저장소의 `vdiv` 가 이미 그렇게 처리돼 있다. 두 함수가 반대 규약을 갖는 것이
  가장 나쁜 결과다.
- 이름이 애매해서 어느 쪽도 자연스럽지 않은 경우에만 주석을 고치는 쪽을 택하고,
  **왜 그렇게 정했는지 주석에 남겨라.**
- **동작을 바꾸는 모든 수정은 보고서에 별도로 모아라.** 다운스트림이 현재 동작에
  맞춰 보상하고 있을 수 있다.

### 다운스트림 영향 확인 필수

ultrasync 가 현재 호출하는 함수 목록

```
vdsp.Biquad   vdsp.FFT      vdsp.SplitComplex  vdsp.ctoz     vdsp.ztoc
vdsp.sve_svesq vdsp.vdpsp   vdsp.vflt16        vdsp.vmul     vdsp.vrvrs
vdsp.vsdiv    vdsp.vsmul    vdsp.vspdp         vdsp.zvabs    vdsp.zvmags
vdsp.zvmul
```

이 목록의 함수는 **최우선 검증 대상**이며, 동작이 바뀌는 수정을 하면 보고서 맨 앞에
크게 표시하라. (참고: `vsub` 는 현재 ultrasync 가 쓰지 않으므로 고쳐도 안전하다.)

## 테스트 설계 규칙 — 여기서 실수하면 멀쩡한 함수를 망가뜨린다

**vDSP/vForce 는 IEEE 정확 반올림이 아니다.** 실측으로 확인된 사실:

- `vDSP_vdivD` 는 일부 입력에서 스칼라 `/` 대비 **1 ulp** 어긋난다 (역수 추정 후 정련 구현).
- `vForce` 의 `sqrt` 도 마찬가지로 fast 구현이다.

따라서 테스트 허용오차를 연산 성격에 따라 나눠라:

- **정확 일치를 요구할 것**: 덧셈, 뺄셈, 곱셈, 복사, ramp, min/max, clip, 정수 변환, 정렬
- **근사 비교할 것 (`expectApproxEqRel`, 상대오차 명시)**: 나눗셈, 제곱근/역제곱근,
  초월함수(vForce 전반), FFT/DFT, 누산이 들어가는 리덕션(`sve`, `dotpr` — 벡터 누산은
  스칼라 좌→우 누산과 결합순서가 다르다)

**정확 일치를 잘못 요구해서 테스트가 깨지면, 함수를 고치지 말고 테스트를 고쳐라.**
반대로 근사 비교로 도망쳐서 진짜 버그를 덮지도 마라 — 1 ulp 와 부호 반전은 구분된다.

각 테스트는 이런 모양이어야 한다:

- 스칼라 참조 구현을 테스트 안에 직접 적는다 (헤더의 수식을 그대로 옮긴 것)
- 비대칭 입력을 쓴다. **`a`와 `b`가 대칭이면 인자 순서 버그가 안 잡힌다** —
  이번 `vsub` 버그가 기존 테스트를 통과했다면 그게 이유다
- 음수, 0, 길이 1, 홀수 길이를 포함한다
- 가능하면 in-place(`out == a`) 호출도 검증한다

## 우선순위 (475개를 한 번에 하지 마라)

1. **`swapped` 경고 8개 함수** — 위 표의 ❓ 3건 포함. 여기서 시작한다.
2. **ultrasync 사용 16개 함수** — 프로덕션이 지금 의존 중.
3. **`vdsp/vecop.zig`, `zvecop.zig`, `reduction.zig`, `clip.zig`, `util.zig`, `convert.zig`**
   — 비가환 연산과 인자 순서가 많은 곳.
4. **`vdsp/fft.zig`, `dft.zig`, `fixed_fft.zig`** — 스케일링 규약(vDSP FFT 는 정규화되지
   않고 `zrip` 계열은 2배 규약), split-complex 패킹(DC/Nyquist 를 `imagp[0]` 에 채워넣음),
   setup 생성/해제 수명. 어렵지만 틀리면 조용히 틀린다.
5. **`vdsp/biquad.zig`, `conv.zig`, `matrix.zig`, `ramp.zig`, `dotp.zig`**
6. **`vforce/root.zig`** (42개) — 대부분 단순 매핑이라 빠르다.
7. **`vimage/`** (168개) — ultrasync 미사용. 에러코드 규약과 버퍼 정렬이 vDSP 와 전혀 달라
   품이 많이 든다. **여기까지 오면 진행 상황을 보고하고 계속할지 물어라.**

## 산출물

1. **수정된 저장소** — 함수/주석 수정 + 신규 테스트. `zig build test` 가 전부 통과할 것.
2. **커밋 분리** — 최소한 "테스트 추가", "주석 수정(동작 불변)", "동작 수정" 세 종류를
   섞지 마라. 동작 수정은 함수별로 따로 커밋하고 메시지에 헤더 근거를 인용하라.
3. **보고서** (`fix/AUDIT.md` 등):

- 동작이 바뀐 함수 목록 (다운스트림 영향 표시) ← 맨 앞
- 주석만 고친 함수 목록
- 검증했고 문제없던 함수 목록
- 검증하지 못한 함수와 그 이유 (하드웨어 의존, 테스트 작성 불가 등)
- 발견한 결함의 **패턴** — 다음 사람이 같은 실수를 안 하도록

## 하지 말 것

- 추측 기반 "수정". 근거 없으면 미검증으로 남기고 보고하라.
- 테스트 없이 동작 변경.
- 475개를 다 못 끝냈다고 대충 마무리하기. **끝낸 범위를 정확히 보고하는 편이
  전부 훑었다고 말하는 것보다 훨씬 낫다.**
