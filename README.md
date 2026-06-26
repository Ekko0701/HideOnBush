# HideOnBush

HideOnBush는 승인된 개인/업무 사용 시나리오에서 Claude OTel 설정을 Work Mode와 Personal Mode로 전환하는 macOS 메뉴바 앱입니다.

## 제어 대상

- `~/.zshrc` 또는 현재 셸에 맞는 프로파일의 Claude OTel export 블록
- `~/Library/LaunchAgents/com.megastudy.otel.plist`
- 현재 `launchctl` GUI 환경에 들어간 알려진 `CLAUDE_*`, `OTEL_*` 값

## 모드

- Work Mode: 백업된 셸 블록과 LaunchAgent를 복원하고 `launchctl setenv`로 GUI 환경도 다시 설정합니다.
- Personal Mode: 셸 블록을 제거하고 LaunchAgent를 unload/remove한 뒤, 추적 대상 GUI 환경 변수를 `launchctl unsetenv`로 제거합니다.

이미 실행 중인 앱은 예전 환경 변수를 계속 들고 있습니다. 모드 전환 후에는 Claude Desktop, VSCode, Cursor, JetBrains IDE, Terminal, iTerm을 완전히 종료한 뒤 다시 실행해야 합니다.

## 백업 위치

처음 실행할 때 현재 Work 설정을 아래 위치에 백업합니다.

```text
~/Library/Application Support/HideOnBush
```

Work Mode 복원 시 가능하면 이 백업본을 그대로 사용하므로, 기존 회사 설정의 세부 값이 임의로 바뀌지 않습니다.

## 빌드

```bash
./scripts/build.sh
```

앱 번들은 아래 위치에 생성됩니다.

```text
dist/HideOnBush.app
```

## 실행

```bash
./scripts/run.sh
```

또는 Finder에서 `dist/HideOnBush.app`를 직접 열면 됩니다.

## 메뉴

- `Personal Mode로 전환`
- `Work Mode로 전환`
- `상태 새로고침`
- `상태 클립보드에 복사`
- `셸 프로파일 열기`
- `LaunchAgents 폴더 열기`

## Homebrew 배포

개인 배포용 Homebrew tap을 따로 만들고, GitHub Release ZIP을 cask에서 받게 하는 방식이 가장 단순합니다.

릴리스 ZIP과 cask 파일 생성:

```bash
OWNER_REPO=your-github-user/HideOnBush ./scripts/package-homebrew.sh 0.1.0
```

생성물:

```text
release/HideOnBush-v0.1.0-macos-arm64.zip
release/homebrew/Casks/hideonbush.rb
```

배포 흐름:

1. GitHub Release `v0.1.0`을 만들고 `HideOnBush-v0.1.0-macos-arm64.zip`을 업로드합니다.
2. 별도 tap repo를 만듭니다. 예: `homebrew-hideonbush`.
3. 생성된 `hideonbush.rb`를 tap repo의 `Casks/hideonbush.rb`에 커밋합니다.
4. 사용자는 아래처럼 설치합니다.

```bash
brew tap your-github-user/hideonbush
brew install --cask hideonbush
```

업데이트 시에는 새 버전 ZIP을 GitHub Release에 올리고, tap repo의 `version`과 `sha256`이 반영된 cask 파일을 갱신합니다.
