# Body Note

기초 훈련장에서 재활과 훈련을 기록하며 동물 선수를 키우는 한국어 iPhone 앱입니다. 기록은 기기의 앱 전용 저장소에 보관합니다.

## Windows에서 화면 보기

저장소를 내려받아 [Preview/index.html](Preview/index.html)을 Edge 또는 Chrome에서 엽니다. 서버나 별도 설치 없이 동작하는 브라우저 시안입니다. SwiftUI 앱과 같은 그림을 사용하고, 시안의 데이터는 이 브라우저에 별도로 저장합니다.

1. 빈 일지의 첫 화면에는 러닝복을 입은 고양이와 기초 훈련장이 보입니다. 오른쪽 위 **선수 선택**에서 고양이·강아지·토끼·너구리 중 하나를 고릅니다.
2. **다음 기록의 스킨**에서 러닝, 필드하키, 웨이트, 기초 재활 유니폼 중 하나를 고릅니다. **첫 훈련 기록하기**에서 훈련·재활·휴식을 선택하고 세트를 입력합니다. 예를 들어 필드하키 스킨을 입은 토끼로 스쿼트를 기록할 수 있습니다.
3. 예전 기록을 가져오는 흐름은 브라우저 라커룸에서 **예시 일지 불러오기**를 누른 뒤 확인할 수 있습니다. **지난 기록 가져오기 → 케이블 로우**에서 마지막 세트를 고쳐 확정하면 원본과 오늘 기록이 일지에 각각 남습니다.

훈련이나 재활을 확정하면 해당 일지에 선수와 스킨을 함께 저장합니다. **오늘**과 **모험**의 훈련장에는 가장 최근 훈련·재활 일지의 캐릭터가 보입니다. **일지** 목록과 상세 화면에는 각 기록에 저장한 캐릭터가 보입니다. 쉬는 날에는 직전 훈련의 캐릭터가 훈련장에 남습니다.

**지난 기록 가져오기**는 원래 스킨을 현재 선택한 동물에게 입혀 새 초안을 엽니다. 스킨은 초안에서 바꿀 수 있습니다. 캐릭터를 저장하기 전에 작성한 일지는 처음 열 때 프로필 동물과 기록의 종목을 조합합니다. 종목이 비어 있으면 프로필 스킨을 쓰고, 옛 축구·농구 기록은 원래 종목명과 러닝 스킨을 표시합니다. 예전 드릴의 상세 수치는 원래 일지에서 읽을 수 있습니다. 이를 가져오면 원래 거리 또는 시도 횟수가 일반 세트에 들어갑니다.

## iPhone 앱 실행

macOS의 Xcode 16 이상에서 [BodyNote.xcodeproj](BodyNote.xcodeproj)를 열고 **BodyNote** 스킴과 iOS 17 이상 iPhone 시뮬레이터를 선택한 뒤 실행합니다. 실제 iPhone에서는 타깃의 **Signing & Capabilities**에서 본인의 개발 팀을 선택합니다. 개인별 서명 정보는 Xcode에서 설정합니다.

## 기록과 성장

- **오늘**에서 훈련·재활·휴식을 기록합니다. 운동별 세트에 횟수·시간·거리, 중량과 좌우 방향을 남길 수 있습니다.
- 운동마다 세트별로 무게와 횟수를 입력합니다. 예를 들어 케이블 로우를 1세트 20 kg × 12회, 2세트 22.5 kg × 10회, 3세트 25 kg × 8회로 기록할 수 있습니다. **세트 추가**는 직전 세트의 값으로 새 줄을 엽니다. 맨몸 운동은 무게 칸을 비워 두면 됩니다.
- **지난 기록 가져오기**는 새 초안을 엽니다. 운동과 세트 값을 가져오고, 운동 당시의 느낌과 메모는 새로 작성합니다. 작성 시간 제한은 없습니다.
- **오늘 기록으로 확정**할 때 새 일지와 기기 현지 날짜가 정해집니다. 이전 일지를 수정하면 원래 날짜를 유지합니다.
- **일지**의 달력과 운동별 기록 카드에서 수행 기록을 찾습니다. 다음에 볼 메모를 운동에 고정하거나, 다음 날 몸 상태를 원래 일지에 덧붙일 수 있습니다.
- **모험**은 재활·훈련을 확정한 날짜마다 10 XP를 계산합니다. 레벨 간격은 100 XP입니다. 훈련 기록판에 첫 5일의 도장을 표시합니다. 3일 기록하면 콘 코스가, 6일 기록하고 한 줄 회고를 쓰면 매트 구역이 열립니다. 휴식일에는 훈련장에 휴식 표시가 생깁니다.
- **선수 선택 → 동작 미리보기**에서 고른 동물과 유니폼으로 호흡, 옆으로 스트레칭, 출발 준비, 달리기, 성장 점프를 반복 재생합니다. 같은 화면에서 다음 동작을 고를 수 있습니다. Windows 라커룸에서도 동작을 고르면 선택한 버튼과 화면에 보이는 훈련장의 선수가 함께 움직입니다. 기기에서 동작 줄이기를 켜면 각 동작의 대표 자세를 표시합니다.
- 새 훈련 날짜를 확정하면 달리기, 100 XP 경계를 넘으면 성장 점프가 보입니다.
- **나의 마일스톤**은 시작일부터 지정한 운동을 기록한 날짜를 셉니다. 목표 화면에서 해당 날짜의 일지를 다시 열 수 있습니다.

### 동작 도감

훈련·재활 기록의 **운동 이름**에 `스퀏`, `팔굽혀`, `plank`처럼 입력하면 관련 동작이 나타납니다. 제안을 눌러 이름을 채우거나 원하는 이름을 직접 입력할 수 있습니다.

동작 이름이 떠오르지 않을 때는 **부위별 동작 찾기**를 엽니다. **무릎**을 고른 뒤 **레그 익스텐션**을 누르면 자세 그림, 동작 설명, 도구와 기록 단위를 볼 수 있습니다. **이 동작 선택**을 누르면 작성하던 운동으로 돌아옵니다. 새 운동에서 플랭크를 고르면 단위가 초로 설정됩니다. 이미 작성한 세트나 지난 기록은 입력한 무게·횟수·단위를 유지합니다. **일지 → 동작 도감**에서도 16개 동작을 둘러볼 수 있습니다.

도감 데이터와 그림은 앱과 Windows 시안에 포함되어 오프라인으로 열립니다. 동작을 추가할 때는 [도감 원본](BodyNoteCore/Sources/BodyNoteCore/Resources/exercise-catalog.json)을 수정하고 `node Scripts/sync-exercise-catalog.mjs`로 시안을 갱신합니다. [동작 그림 출처와 라이선스](BodyNoteCore/Sources/BodyNoteCore/Resources/ExerciseArt/ATTRIBUTION.md)

### 기초 훈련장 기록판

횟수로 기록한 운동은 모든 스킨에서 비교할 수 있습니다. **기초 훈련장 기록판**에서 운동 이름·도구·세트별 무게와 방향·앞 세트의 횟수가 같은 두 훈련을 찾아 마지막 세트의 변화를 보여줍니다. 여러 세트라면 세트 간 휴식 시간도 입력합니다. 날짜를 누르면 해당 일지가 열립니다.

**이 조건으로 목표 만들기**에서 마지막 세트의 목표 횟수를 정합니다. 시작일부터 서로 다른 훈련 세 건에서 달성하면 숙련 배지를 받습니다. 스킨을 바꿔서 기록해도 같은 운동 조건이면 함께 셉니다.

## 주요 코드와 검증

| 확인할 동작 | 위치 |
| --- | --- |
| 초안 생성과 세트 입력 | [JournalEntry.swift](BodyNoteCore/Sources/BodyNoteCore/JournalEntry.swift), [JournalEditor.swift](BodyNote/JournalEditor.swift) |
| 확정·수정, XP, 개인 목표 계산 | [Notebook.swift](BodyNoteCore/Sources/BodyNoteCore/Notebook.swift) |
| 세트 조건, 성장 비교와 배지 | [Performance.swift](BodyNoteCore/Sources/BodyNoteCore/Performance.swift), [GrowthBoard.swift](BodyNote/GrowthBoard.swift), [브라우저 비교 로직](Preview/performance.js) |
| 파일 저장·읽기, 화면 상태 반영 | [NotebookFile.swift](BodyNoteCore/Sources/BodyNoteCore/NotebookFile.swift), [BodyNoteApp.swift](BodyNote/BodyNoteApp.swift) |
| 운동별 기록과 다음 날 메모 | [JournalView.swift](BodyNote/JournalView.swift) |
| 선수와 다음 기록의 스킨 | [Athlete.swift](BodyNoteCore/Sources/BodyNoteCore/Athlete.swift), [TodayView.swift](BodyNote/TodayView.swift) |
| 훈련장 화면과 마일스톤 | [TrainingGround.swift](BodyNote/TrainingGround.swift), [AdventureView.swift](BodyNote/AdventureView.swift) |

```sh
swift test --package-path BodyNoteCore
xcodebuild -project BodyNote.xcodeproj -scheme BodyNote -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

첫 명령은 Swift와 Foundation으로 기록·저장 규칙을 검증합니다. 두 번째 명령은 Mac에서 SwiftUI 앱을 빌드합니다. [GitHub Actions](.github/workflows/ios.yml)는 푸시 후 두 명령을 실행합니다.

## 아트 리소스

훈련장 배지는 제공된 디자인 초안에서 추출했습니다. 첫 화면부터 훈련장 배경 위에 선택한 동물·유니폼·동작을 겹쳐 표시합니다. 앱과 Windows 시안이 같은 파일을 사용합니다. [아트 카탈로그](BodyNote/Assets.xcassets)

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
