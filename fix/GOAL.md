./REQUEST.md 내용에 따라 accelerate 바인딩을 전수 검증, 수정하시오
각 단계별로 fix/CHECKLIST.md 에 체크하며 CHECKLIST.md 의 모든 항목이 체크 될때까지 수행

## 체크리스트 관리 스크립트

`fix/checklist.sh`는 `fix/CHECKLIST.md`를 읽어 전체 진행률과 남은 모듈·파일·함수를 요약한다.
기본적으로 스크립트 위치를 기준으로 `fix/CHECKLIST.md`를 찾으므로 저장소 어느 위치에서 실행해도 된다.

```sh
# 전체 상태와 남은 항목 조회
./fix/checklist.sh

# 모듈별 조회
./fix/checklist.sh module vDSP

# 파일별 조회
./fix/checklist.sh file src/vdsp/vecop.zig

# 함수 검증 완료 처리: CHECKLIST.md의 [ ]를 [x]로 변경하고 상태 요약 출력
./fix/checklist.sh check src/vdsp/vecop.zig vadd
```

`check` 명령은 함수명만 지정할 수도 있으며, 동일한 함수명이 여러 파일에 있으면 파일 경로를 함께 지정해야 한다.
체크리스트 파일을 별도 경로로 시험할 때는 각 명령의 마지막 인자로 경로를 전달한다.
