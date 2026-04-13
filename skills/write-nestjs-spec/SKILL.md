---
name: write-nestjs-spec
description: NestJS 백엔드 모듈의 API 스펙 문서(.spec.md)를 작성한다. 모듈명을 인자로 받아 엔티티, API 명세, 유효성 검증, 비즈니스 규칙 등을 포함한 구조화된 스펙 문서를 생성한다. 사용 예시 - /write-spec payment, /write-spec notification. 새로운 기능 모듈의 API 설계를 문서화할 때, 기존 모듈의 스펙을 작성할 때, 또는 API 명세서가 필요할 때 사용한다.
---

# write-nestjs-spec

NestJS 백엔드 모듈의 API 스펙 문서를 작성하는 skill.

## Workflow

### 1. 모듈명 확인

인자로 전달된 모듈명(예: `payment`)을 확인한다. 인자가 없으면 사용자에게 모듈명을 물어본다.

### 2. 기존 모듈 여부 확인

프로젝트에 해당 모듈이 이미 구현되어 있는지 확인한다 (`src/{module-name}/` 디렉토리 존재 여부).

- **모듈이 이미 존재하는 경우**: 사용자에게 질문하지 않고, 기존 코드(엔티티, 컨트롤러, 서비스, DTO)를 분석하여 스펙 문서를 역으로 작성한다. 코드에서 엔드포인트, 유효성 검증, 비즈니스 규칙, 에러 케이스를 추출한다.
- **모듈이 없는 경우 (신규)**: 아래 절차에 따라 사용자에게 질문하여 정보를 수집한다.

### 3. 정보 수집 (신규 모듈인 경우)

사용자에게 다음을 순차적으로 질문한다. 한 번에 많은 질문을 하지 말고 2~3개씩 나누어 물어본다.

**1차 질문 — 개요:**
- 이 모듈의 목적과 역할은?
- 어떤 엔티티(테이블)가 필요한가?
- 주요 컬럼과 타입은?

**2차 질문 — API:**
- 어떤 API 엔드포인트가 필요한가? (CRUD 중 어떤 것?)
- 각 엔드포인트의 인증 요구사항은?
- 특별한 비즈니스 규칙이 있는가?
- 실패할 수 있는 케이스는? (예: 권한 없음, 중복 요청, 리소스 미존재 등)

필요 시 추가 질문을 한다.

### 4. 스펙 문서 생성

[spec-template.md](references/spec-template.md)의 구조를 따라 스펙 문서를 작성한다.

**출력 위치:** `src/{module-name}/{module-name}.spec.md`

### 5. 프로젝트 컨벤션 적용

스펙 작성 시 아래 프로젝트 컨벤션을 반영한다:

- **엔티티**: `CoreEntity` 상속 (`id`, `created_at`, `updated_at`). `created_at`/`updated_at`은 `select: false`이므로 조회 시 명시적 select 필요.
- **출력 형식**: `{ isSuccess: true }` 패턴 (`DtoOutput`).
- **인증**: `AuthGuard` 사용. `x-jwt` 헤더 기반.
- **유효성 검증**: `class-validator` + `class-transformer`, global `ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true })`.
- **예외 처리**: `assert400(condition, message)` 사용 (`src/util/exception.ts`).
- **엔티티 경로**: `src/database/produce_entity/` (glob 자동 인식).
- **모듈 구조**: `module.ts`, `controller.ts`, `service.ts`, `dto/`, `*.e2e.spec.ts`.

### 6. 리뷰 및 수정

생성된 스펙을 사용자에게 보여주고 피드백을 받아 수정한다.
