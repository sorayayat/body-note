# 운동일지

운동과 재활의 세트별 수행량을 기록하고, 날짜별·운동별 변화와 최근 7일의 운동량을 돌아보는 한국어 iPhone 앱입니다. 사용자가 고른 동물은 일지를 바탕으로 활동을 돌아보고 경기 준비를 함께 하는 코치입니다.

## Windows에서 화면 보기

저장소를 내려받아 [Preview/index.html](Preview/index.html)을 Edge 또는 Chrome에서 엽니다. 서버나 별도 설치 없이 동작하는 브라우저 시안입니다. SwiftUI 앱과 같은 그림을 사용하고, 시안의 데이터는 이 브라우저에 별도로 저장합니다.

1. **오늘**에서 최근 7일을 확인하고 **첫 훈련 기록하기**를 누릅니다. 훈련·재활·휴식 중 하나를 고르고 세트별 무게와 수행량을 입력합니다. **일지**에서 날짜나 운동으로 다시 찾을 수 있습니다.
2. **오늘 → 훈련장 보기**에서 현재 선수와 XP, 마일스톤을 확인합니다. 세트별 성장이나 좌우 변화를 보려면 **훈련 기록판 보기**를 누릅니다. 확정한 일지가 있으면 오늘 화면에서도 기록판을 바로 열 수 있습니다.
3. **선수·스킨 변경**은 오늘과 훈련장 양쪽에서 라커룸을 엽니다. 고양이·강아지·토끼·너구리 중 하나를 고른 다음 러닝, 필드하키, 웨이트, 기초 재활 유니폼을 입혀 볼 수 있습니다. 선택은 바로 저장되며 뒤로 가면 들어왔던 화면으로 돌아갑니다.
4. 예전 기록을 가져오는 흐름은 브라우저 미리보기의 **예시 일지 불러오기**로 확인할 수 있습니다. **지난 기록 가져오기 → 케이블 로우**에서 마지막 세트를 고쳐 확정하면 원본과 오늘 기록이 일지에 각각 남습니다.

훈련이나 재활을 확정하면 해당 일지에 선수와 스킨을 함께 저장합니다. **오늘**의 훈련장 요약과 **기초 훈련장**에는 가장 최근에 확정한 훈련·재활 일지의 캐릭터가 보입니다. 첫 기록 전에는 라커룸에서 고른 선수가 보입니다. **일지** 목록과 상세 화면에는 각 기록에 저장한 캐릭터가 보입니다. 쉬는 날에는 직전 훈련의 캐릭터가 훈련장에 남습니다.

**지난 기록 가져오기**는 원래 스킨을 현재 선택한 동물에게 입혀 새 초안을 엽니다. 스킨은 초안에서 바꿀 수 있습니다. 캐릭터를 저장하기 전에 작성한 일지는 처음 열 때 프로필 동물과 기록의 종목을 조합합니다. 종목이 비어 있으면 프로필 스킨을 쓰고, 옛 축구·농구 기록은 원래 종목명과 러닝 스킨을 표시합니다. 예전 드릴의 상세 수치는 원래 일지에서 읽을 수 있습니다. 이를 가져오면 원래 거리 또는 시도 횟수가 일반 세트에 들어갑니다.

## iPhone 앱 실행

Mac의 Xcode 26 이상에서 **BodyNote** 스킴을 선택합니다. 지원하는 최소 버전은 iOS 17입니다. 실제 iPhone을 기기로 선택하고 앱 타깃의 **Signing & Capabilities → Team**에 본인의 팀을 지정한 뒤 **Run**을 누르면 홈 화면에 설치됩니다. 앱 표시 이름은 운동일지입니다. 기존에 설치한 사용자의 일지를 이어서 읽도록 번들 ID와 저장 경로를 유지합니다. [Xcode 프로젝트](BodyNote.xcodeproj)

### 내부 베타

Apple Silicon Mac에서 앱 화면을 바로 보려면 GitHub의 **Actions → Workout Log iOS**에서 해당 커밋의 성공한 실행을 엽니다. **Artifacts → WorkoutLog-iOS-Simulator-arm64**를 다운로드해 안쪽 ZIP까지 풀고, Xcode에서 iOS 26 이상 iPhone 시뮬레이터를 실행한 뒤 `BodyNote.app`을 시뮬레이터 창에 놓습니다. 이 앱은 그 실행에서 UI 테스트를 통과한 빌드입니다.

1. 아래 검증을 실행하고 시뮬레이터 테스트 결과를 확인합니다. 지원하는 iPhone에서는 Apple Intelligence를 켜고 운동 전 긴장에 대해 질문해 모델 응답을 확인합니다. **코치 → 회복 알림 설정**에서 알림을 허용한 후 불편함을 기록해 다음 날 한 번 도착하는지도 확인합니다.
2. Apple Developer Program 팀에서 App Store Connect에 동일한 번들 ID로 앱을 등록합니다. Xcode에서 배포 팀과 새 빌드 번호를 확인하고, 실제 iOS 기기 대상에서 **Product → Archive → Distribute App**으로 업로드합니다. [Apple 빌드 업로드 안내](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
3. 빌드 처리가 끝나면 **App Store Connect → TestFlight**에서 해당 빌드를 내부 그룹에 추가하고 테스터를 지정합니다. CI는 서명 없는 기기 빌드와 시뮬레이터 테스트를 실행하며, 배포는 이 업로드·그룹 배정 단계에서 이루어집니다. [Apple 내부 테스터 안내](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)

## 기록 추적과 코치

- **최근 7일**은 오늘을 포함한 현지 날짜로 운동한 일수, 훈련·재활 횟수, 세트 수를 집계합니다. 같은 날 두 번 훈련하면 1일·2회로 표시합니다. 날짜를 누르면 계산에 사용한 원래 일지를 볼 수 있습니다. 휴식을 남긴 날도 달력에서 확인할 수 있습니다.
- **작성 중**에는 입력한 새 일지, 이전 일지의 수정 초안과 루틴이 각각 보관됩니다. 운동 도감을 읽고 돌아오거나 앱을 종료한 뒤에도 이어서 수정할 수 있습니다. 확정해야 주간 합계와 XP에 반영됩니다. 동물별 대화와 보내기 전 문장도 기기에 보관합니다.
- **몸 상태와 회복**은 사용자가 남긴 통증·불편 항목과 연속 운동일을 바탕으로 원래 일지와 함께 안내를 표시합니다. 통증으로 중단했거나 심해졌다고 입력하면 아픈 동작을 멈추고 필요시 진료를 받도록 안내합니다. 알림을 허용하면 해당 기록 다음 날 현지 오전 9시에 회복 확인을 한 번 예약하고, 잠금 화면에는 일반적인 확인 문구를 표시합니다. [NHS의 통증·부종 악화 시 도움받기 안내](https://www.nhs.uk/conditions/sprains-and-strains/)
- **동물 코치**는 확정한 수치로 활동 요약을 계산합니다. 지원하는 iOS 26 이상 기기에서 Apple Intelligence 모델이 준비되면 질문의 주제를 가르고 경기 집중·자신감처럼 비임상적인 운동 대화에 짧게 답합니다. 같은 동물의 직전 관련 대화를 이어갈 수 있습니다. 모델 미지원·꺼짐·오류 상황과 브라우저 시안에서는 기기에 포함된 기본 코칭을 사용합니다. 통증과 위기 신호에는 정해진 안내를 사용합니다. [Apple Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)

### 데이터와 향후 연결

iPhone은 기존 v1·v2 일지를 열 수 있고 다음 저장부터 v3 형식을 사용합니다. v3는 숙련 목표 입력을 원본 기록과 운동 조건에 함께 보관합니다. 이전 앱은 지원하는 버전보다 높은 파일을 열 때 쓰기를 중단합니다.

숙련 목표를 쓰다가 원본 운동이나 세트 조건을 바꾸면 해당 목표의 생성을 멈추고 조건을 다시 선택할 수 있습니다. 마지막 세트 횟수만 달라지면 같은 조건으로 이어 씁니다. 이전 버전에서 쓴 목표값은 원문으로 보관하고, 사용할 운동을 확인한 뒤 직접 불러올 수 있습니다.

Windows에서 두 창에 서로 다른 일지를 열면 각 창의 운동과 세트가 함께 저장됩니다. 같은 초안을 양쪽에서 고치면 **새 초안으로 보관**을 눌러 두 버전을 남길 수 있습니다. **오늘 → 작성 중**에는 첫 세트의 중량·수행량과 메모가 보여서 같은 이름으로 작성한 운동도 구분할 수 있습니다.

iPhone은 앱 전용 파일을 원자적으로 갱신하고 iOS 파일 보호를 적용합니다. Windows 시안은 해당 브라우저의 로컬 저장소를 사용하며, 두 저장소는 독립적입니다. 현재 일지·대화 기능의 처리 경로는 기기 안에서 끝납니다. 향후 동기화는 저장소 인터페이스에, 서버 코치는 코칭 제공자 인터페이스에 연결할 수 있습니다. 서버 기능을 추가할 때는 전송할 기록이나 대화 맥락의 범위를 보여 주고 동의를 받은 뒤 사용하도록 설계합니다. [저장소 인터페이스](BodyNoteCore/Sources/BodyNoteCore/NotebookRepository.swift) · [기기 저장](BodyNoteCore/Sources/BodyNoteCore/NotebookFile.swift) · [코칭 인터페이스](BodyNoteCore/Sources/BodyNoteCore/TrainingCoach.swift)

## 기록과 성장

- **오늘**에서 훈련·재활·휴식을 기록합니다. 운동별 세트에 횟수·시간·거리, 중량과 좌우 방향을 남길 수 있습니다.
- 운동마다 세트별로 무게와 횟수를 입력합니다. 예를 들어 케이블 로우를 1세트 20 kg × 12회, 2세트 22.5 kg × 10회, 3세트 25 kg × 8회로 기록할 수 있습니다. **세트 추가**는 직전 세트의 값으로 새 줄을 엽니다. 맨몸 운동은 무게 칸을 비워 두면 됩니다.
- **지난 기록 가져오기**는 새 초안을 엽니다. 운동과 세트 값을 가져오고, 운동 당시의 느낌과 메모는 새로 작성합니다. 작성 시간 제한은 없습니다.
- **오늘 기록으로 확정**할 때 새 일지와 기기 현지 날짜가 정해집니다. 이전 일지를 수정하면 원래 날짜를 유지합니다.
- **일지**의 달력과 운동별 기록 카드에서 수행 기록을 찾습니다. 다음에 볼 메모를 운동에 고정하거나, 다음 날 몸 상태를 원래 일지에 덧붙일 수 있습니다.
- **기초 훈련장**은 재활·훈련을 확정한 날짜마다 10 XP를 계산합니다. 레벨 간격은 100 XP입니다. 훈련장 배경의 기록판에 첫 5일의 도장을 표시합니다. 3일 기록하면 콘 코스가, 6일 기록하고 한 줄 회고를 쓰면 매트 구역이 열립니다. 휴식일에는 훈련장에 휴식 표시가 생깁니다.
- **선수·스킨 변경 → 동작 미리보기**에서 고른 동물과 유니폼으로 호흡, 옆으로 스트레칭, 출발 준비, 달리기, 성장 점프를 반복 재생합니다. Windows 미리보기에서는 옆 패널의 동작을 눌러도 라커룸이 열립니다. 기기에서 동작 줄이기를 켜면 각 동작의 대표 자세를 표시합니다.
- 새 훈련 날짜를 확정하면 달리기, 100 XP 경계를 넘으면 성장 점프가 보입니다.
- **나의 마일스톤**은 시작일부터 지정한 운동을 기록한 날짜를 셉니다. 목표 화면에서 해당 날짜의 일지를 다시 열 수 있습니다.

### 내 루틴

훈련 일지가 0건이어도 **오늘 → 내 루틴 → 루틴 만들기**에서 운동과 세트를 기기에 저장할 수 있습니다. 오늘의 기록을 작성하는 중이라면 **루틴만 저장**을 눌러 이름과 세트를 확인하고 저장하세요. 작성하던 일지로 돌아온 뒤 닫아도 루틴은 보관됩니다. 이미 확정한 일지는 상세 화면의 **내 루틴으로 저장**에서 가져올 수 있습니다.

첫 루틴은 자동으로 기본이 되며, 다음부터 **오늘 훈련 기록하기**를 누르면 운동 순서·도구·단위·세트별 수행량과 중량·좌우·세트 간 휴식이 채워집니다. 훈련 일수와 XP는 일지를 확정할 때 계산합니다.

그날의 스킨은 오늘 선택한 것을 사용하고, 몸 상태와 메모는 매번 새로 입력합니다. 일지를 확정하면 그날의 실제 수행량을 기록합니다. 기본값을 바꾸려면 **내 루틴 → 루틴 편집**에서 세트를 고치거나 다른 루틴의 **기본 루틴으로 지정**을 누릅니다. 하루만 다른 계획을 쓰고 싶으면 **이 루틴으로 기록** 또는 **빈 기록으로 시작**을 누릅니다. **기본 루틴 해제**를 누르면 이후 새 일지를 빈 양식으로 엽니다.

### 동작 도감

훈련·재활 기록의 **운동 이름**에 `스퀏`, `팔굽혀`, `plank`처럼 입력하면 관련 동작이 나타납니다. 제안을 눌러 이름을 채우거나 원하는 이름을 직접 입력할 수 있습니다.

동작 이름이 떠오르지 않을 때는 **부위별 동작 찾기**를 엽니다. **무릎**을 고른 뒤 **레그 익스텐션**을 누르면 자세 그림, 동작 설명, 도구와 기록 단위를 볼 수 있습니다. **이 동작 선택**을 누르면 작성하던 운동으로 돌아옵니다. 새 운동에서 플랭크를 고르면 단위가 초로 설정됩니다. 이미 작성한 세트나 지난 기록은 입력한 무게·횟수·단위를 유지합니다. **일지 → 동작 도감**에서도 16개 동작을 둘러볼 수 있습니다.

도감 데이터와 그림은 앱과 Windows 시안에 포함되어 오프라인으로 열립니다. 동작을 추가할 때는 [도감 원본](BodyNoteCore/Sources/BodyNoteCore/Resources/exercise-catalog.json)을 수정하고 `node Scripts/sync-exercise-catalog.mjs`로 시안을 갱신합니다. [동작 그림 출처와 라이선스](BodyNoteCore/Sources/BodyNoteCore/Resources/ExerciseArt/ATTRIBUTION.md)

### 훈련 기록판

횟수로 기록한 운동은 모든 스킨에서 비교할 수 있습니다. **훈련 기록판**에서 운동 이름·도구·세트별 무게와 방향·앞 세트의 횟수가 같은 두 훈련을 찾아 마지막 세트의 변화를 보여줍니다. 여러 세트라면 세트 간 휴식 시간도 입력합니다. 날짜를 누르면 해당 일지가 열립니다.

**이 조건으로 목표 만들기**에서 마지막 세트의 목표 횟수를 정합니다. 시작일부터 서로 다른 훈련 세 건에서 달성하면 숙련 배지를 받습니다. 스킨을 바꿔서 기록해도 같은 운동 조건이면 함께 셉니다.

### 좌우 변화

재활 기록에서는 세트마다 **왼쪽** 또는 **오른쪽**을 고릅니다. 일반 훈련에서는 **좌우 나눠 기록**을 누르면 같은 입력란이 열립니다. **오늘 → 훈련장 보기 → 훈련 기록판 보기**에서 양쪽 변화를 비교할 수 있습니다. **일지 → 운동별 → 운동 이름**에서도 해당 운동의 변화를 볼 수 있습니다.

운동 이름·도구·중량·단위가 같은 기록을 모아, 각 방향에서 가장 최근에 확정한 두 일지의 마지막 해당 세트를 비교합니다. 예를 들어 같은 밴드에서 왼쪽은 8회에서 10회로, 오른쪽은 10회에서 10회로 바뀌면 각각 **+2회**, **동일**로 표시합니다. 두 방향을 다른 날 기록해도 각각의 날짜와 수치를 눌러 원래 일지를 열 수 있습니다. 한 쪽을 처음 기록하면 **첫 기록**, 한 번도 입력하지 않은 쪽은 **기록 없음**으로 표시합니다. 양쪽 동시 수행과 방향을 지정하지 않은 세트는 각 방향의 변화 계산에서 제외합니다.

## 주요 코드와 검증

| 확인할 동작 | 위치 |
| --- | --- |
| 초안 생성과 세트 입력 | [JournalEntry.swift](BodyNoteCore/Sources/BodyNoteCore/JournalEntry.swift), [JournalEditor.swift](BodyNote/JournalEditor.swift) |
| 미완성 숫자와 루틴 초안 복원 | [WorkoutDraft.swift](BodyNoteCore/Sources/BodyNoteCore/WorkoutDraft.swift), [브라우저 작업 화면](Preview/workspace.js) |
| 7일 집계와 회복 안내 | [Tracking.swift](BodyNoteCore/Sources/BodyNoteCore/Tracking.swift), [주간 화면](BodyNote/WeeklyTrackingView.swift) |
| 동물별 대화와 기기 모델·알림 | [TrainingCoach.swift](BodyNoteCore/Sources/BodyNoteCore/TrainingCoach.swift), [CoachView.swift](BodyNote/CoachView.swift) |
| 내 루틴 저장과 새 일지 기본값 | [Notebook.swift](BodyNoteCore/Sources/BodyNoteCore/Notebook.swift), [RoutineViews.swift](BodyNote/RoutineViews.swift), [브라우저 루틴](Preview/routines.js) |
| 확정·수정, XP, 개인 목표 계산 | [Notebook.swift](BodyNoteCore/Sources/BodyNoteCore/Notebook.swift) |
| 세트 조건, 성장 비교와 배지 | [Performance.swift](BodyNoteCore/Sources/BodyNoteCore/Performance.swift), [GrowthBoard.swift](BodyNote/GrowthBoard.swift), [브라우저 비교 로직](Preview/performance.js) |
| 좌우 기록 비교와 원본 일지 연결 | [SideProgress.swift](BodyNoteCore/Sources/BodyNoteCore/SideProgress.swift), [SideProgressView.swift](BodyNote/SideProgressView.swift), [브라우저 좌우 카드](Preview/side-progress.js) |
| 파일 저장·읽기, 화면 상태 반영 | [NotebookFile.swift](BodyNoteCore/Sources/BodyNoteCore/NotebookFile.swift), [BodyNoteApp.swift](BodyNote/BodyNoteApp.swift) |
| 운동별 기록과 다음 날 메모 | [JournalView.swift](BodyNote/JournalView.swift) |
| 선수와 다음 기록의 스킨 | [Athlete.swift](BodyNoteCore/Sources/BodyNoteCore/Athlete.swift), [TodayView.swift](BodyNote/TodayView.swift) |
| 훈련장 화면과 마일스톤 | [TrainingGround.swift](BodyNote/TrainingGround.swift), [AdventureView.swift](BodyNote/AdventureView.swift) |

```sh
node --test Preview/tests/*.test.cjs
node Scripts/check-preview.mjs
node --test Scripts/preview-regressions.test.mjs
swift test --package-path BodyNoteCore
bash Scripts/test-ios-beta.sh
```

앞의 세 명령은 Windows에서 실행할 수 있습니다. Node 22 이상과 Edge 또는 Chrome을 사용합니다. 첫 명령은 데이터 로직을, 다음 두 명령은 독립된 임시 브라우저 프로필에서 실제 화면을 검사합니다. 일지 작성과 확정, 훈련장·라커룸 왕복, 검색·달력 복원, 운동별 고정 메모, 두 창에서 같은 기록을 편집하는 경우를 확인합니다. Windows CI의 **WorkoutLog-Windows-Screens**에서 테스트 중 촬영한 오늘·훈련장·라커룸 화면을 받을 수 있습니다. 브라우저 위치는 `WORKOUT_TEST_BROWSER`로 지정할 수 있습니다. [주요 사용 흐름](Scripts/check-preview.mjs) · [독립 회귀 검사](Scripts/preview-regressions.test.mjs) · [Windows CI](.github/workflows/preview.yml)

Swift 패키지 테스트는 일지·성장·코칭 로직을 검사합니다. 마지막 명령은 Mac에서 iOS 26 이상 SDK와 Foundation Models를 확인하고 iPhone용 Release 빌드와 시뮬레이터 UI 테스트를 실행합니다. Xcode 설정의 **Components**에서 iOS 26 이상 시뮬레이터를 설치할 수 있습니다. UI 테스트는 각각 별도 일지로 기록 입력·도감 왕복·재실행·확정, 기본 루틴 복사, 부위와 별칭으로 검색한 동작 선택, 코치의 미전송 문장 복원, 훈련장과 라커룸의 화면 이동을 확인합니다. [UI 테스트](BodyNoteUITests/WorkoutJournalUITests.swift) · [검증 스크립트](Scripts/test-ios-beta.sh) · [GitHub Actions](.github/workflows/ios.yml)

### 베타 가용률 측정

운동 기록 작성·복원·확정, 기본 루틴 불러오기, 부위·별칭으로 동작 선택, 미전송 코치 메시지 복원을 검사합니다. 같은 커밋에서 각 여정을 서로 다른 일지로 다섯 번 실행합니다. iPhone 시뮬레이터와 Windows Edge가 **각각 20회 중 19회 이상** 끝까지 성공하면 목표인 95%를 충족합니다. 실패·누락도 전체 20회에 포함합니다.

커밋 메시지에 `[availability]`가 있는 푸시 또는 수동 실행으로 측정합니다. 해당 Actions 실행의 요약에 환경·여정·회차별 결과가 남습니다. 수정 후에는 새 커밋의 40회를 다시 측정합니다. [가용률 워크플로](.github/workflows/beta-availability.yml)

## 아트 리소스

훈련장 배지는 제공된 디자인 초안에서 추출했습니다. 훈련장을 열면 배경 위에 동물·유니폼·동작을 겹쳐 표시합니다. 앱과 Windows 시안이 같은 파일을 사용합니다. [아트 카탈로그](BodyNote/Assets.xcassets)

<details>
<summary>내장 ImageGen으로 제작한 배경과 선수 유니폼 프롬프트</summary>

**훈련장 배경** · [TrainingTrack](BodyNote/Assets.xcassets/TrainingTrack.imageset/art.png)

> Use case: precise-object-edit. Edit the provided 4:3 training ground illustration as a game background plate. Remove only the large cat athlete and its small ground shadow at the left of the middle foreground. Paint the track, lines and fence naturally behind it. Preserve the identical framing, painterly pixel game-art, park bench, orange cones, green mat, bottle, bright sun, and score board with five empty stamp outlines at right, at their exact positions. The board title reads 훈련 기록판. No animals or athletes anywhere. Full-bleed landscape 4:3, no interface or outer frame.

**종목과 캐릭터** · [러닝 고양이](BodyNote/Assets.xcassets/cat-running.imageset/art.png), [필드하키 토끼](BodyNote/Assets.xcassets/rabbit-fieldHockey.imageset/art.png), [웨이트 강아지](BodyNote/Assets.xcassets/dog-weightTraining.imageset/art.png), [기초 재활 너구리](BodyNote/Assets.xcassets/raccoon-basic.imageset/art.png)

동작 시트의 행은 러닝, 필드하키, 웨이트, 기초 재활 순서이고 열은 고양이, 강아지, 토끼, 너구리 순서입니다. 필드하키 선수는 청록색 유니폼과 잔디용 스틱을, 웨이트 선수는 버건디 운동복과 손목 밴드를 착용합니다. 웨이트 대기 자세에는 덤벨이 있습니다.

**필드하키·웨이트 기본 유니폼 프롬프트**

> Use case: identity-preserve. Body Note game asset, a landscape sprite sheet of exactly eight full-body standing athletes in a precise 4-column × 2-row grid, uniform scale, separate generous transparent gutters. Image 1 supplies the four animal identities and illustration style only; image 2 supplies the neutral standing pose and proportions. Same thick ink outline, warm soft pixel texture, original small eyes and round faces. Each row, left to right: orange striped tabby with long tail, orange Shiba dog with round ears and curled tail, white rabbit with two tall pink-lined ears, gray masked raccoon with ringed tail. TOP row: FIELD HOCKEY, identical petrol-teal short-sleeve jersey with one ivory horizontal band, navy shorts, mustard knee socks, dark turf shoes; each player holds one slender wooden outdoor field hockey stick with a tight J-shaped hook near the feet and a small white turf ball next to it. BOTTOM row: WEIGHT TRAINING, identical muted burgundy sleeveless gym tank, charcoal shorts, cream flat trainers, light wrist wraps, holding one compact dark hex dumbbell at hip height. Friendly neutral idle, feet planted and facing three-quarters right. Keep props compact and fully inside the cell; same face sizes and baseline per row. True transparent alpha background. No labels, numbers, shadows, ice skates, hockey puck, basketball, soccer graphics, or additional characters.

**동작 시트** · [스트레칭](BodyNote/Assets.xcassets/Motion-stretch.imageset/art.png), [출발 준비](BodyNote/Assets.xcassets/Motion-ready.imageset/art.png), [달리기](BodyNote/Assets.xcassets/Motion-run.imageset/art.png), [달리기 착지](BodyNote/Assets.xcassets/Motion-runContact.imageset/art.png), [성장 점프](BodyNote/Assets.xcassets/Motion-levelUp.imageset/art.png)

필드하키·웨이트 기본 유니폼 시트를 참조 이미지로 넣고, 아래 공통 프롬프트에 동작별 문장을 붙였습니다. 완성한 두 종목을 각 동작 시트의 가운데 두 행에 배치했습니다.

> Use case: identity-preserve. Edit the attached Body Note eight-figure sprite sheet. This reference locks the exact animal identity, face, costume, colors, scale and rendering of every cell. Change only the full-body action as specified. Keep the output a landscape sheet with exactly FOUR columns and TWO rows of completely separated figures, evenly spaced on true transparent alpha. Each row from left: orange tabby cat, orange Shiba dog, white long-eared rabbit, masked gray raccoon. Top row always petrol-teal field hockey jerseys with ivory horizontal band, navy shorts, mustard knee socks and short curved outdoor hockey sticks. Bottom row always burgundy sleeveless weight-training tops, charcoal shorts, ivory wrist wraps and cream trainers. Face three-quarters right, center figures in equal cells with clear generous margins all around gear, ears and tails; common foot baseline and equal head scale per row. Crisp warm outlined chibi game art, all four animals in both kits, no written text, shadows, motion trails, scenery, basketball, or soccer balls.

- **stretch** — Pose for all eight: a clear low side lunge to stretch. Feet much farther apart than idle, one knee bent on the viewer's right, the opposite leg straight to the left. Hands brace the bent knee, chest and face upright; hockey players can rest a paw on the stick near that knee. Weight-training athletes stretch with empty hands.
- **ready** — Pose for all eight: athletic start/ready, low hips, both knees bent, feet staggered, torso leaning forward with one paw near the ground and head looking ahead, clearly crouched. Field hockey athletes keep their stick blade low to receive a small white ball. Weight-training athletes crouch with empty hands ready to move.
- **run** — Animation frame A, all eight RUNNING to the right: both feet in the AIR, wide split stride, one knee driving forward and the other leg kicking back, arms pumping in opposition, body slightly inclined. The free silhouette under each athlete should show a big gap between the feet. Hockey sticks carried diagonally forward in a balanced close dribbling position. Gym athletes' hands are empty during the run.
- **runContact** — Animation frame B, all eight RUNNING to the right in the PASSING / LANDING phase: a single foot planted directly under the hips carrying weight, other knee bent with the boot passing close to the planted leg. A compact upright leg silhouette, plainly different from a wide midair stride; opposite arm forward. Keep the head oriented straight right as in a jogging cycle. Hockey sticks carried diagonally forward in a balanced close dribbling position. Gym athletes' hands are empty during the run.
- **levelUp** — Pose for all eight: delighted compact celebration jump. Both feet lifted, knees softly bent, smiling with eyes closed, paws thrown up in a V. Field hockey athletes lift their stick in one hand (fully inside their own cell), gym athletes raise empty wrapped hands. Do not draw stars, particles, shadows or lettering.

</details>
