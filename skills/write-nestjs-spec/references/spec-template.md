# {모듈명} API 스펙

## 1. 개요

{모듈의 목적과 역할을 1~2문장으로 설명}

---

## 2. 엔티티 (`{EntityName}`)

`CoreEntity`를 상속한다 (`id: number`, `created_at`, `updated_at`).

| 컬럼 | 타입 | nullable | 설명 |
| ---- | ---- | -------- | ---- |
| `id` | `number` (PK, auto inc) | N | CoreEntity 상속 |
| ... | ... | ... | ... |
| `created_at` | `datetime` | N | CoreEntity 상속 |
| `updated_at` | `datetime` | N | CoreEntity 상속 |

### 상태 전이 (해당 시)

```
status_a → status_b
```

---

## 3. API 명세

### 3.N {동작 설명}

```
{METHOD} /{path}
```

- **인증**: 필수 / 불필요

#### Request Body / Query Parameters

```json
{ }
```

#### Response Body

```json
{ "isSuccess": true }
```

#### 에러 응답

| 코드 | 조건 | 메시지 예시 |
| ---- | ---- | ----------- |
| `400` | {어떤 상황에서 발생하는지} | `"{에러 메시지}"` |
| `401` | 인증 토큰 없음 또는 만료 | — |

---

## 4. 유효성 검증 규칙

| 필드 | 타입 | 필수 | 검증 규칙 |
| ---- | ---- | ---- | --------- |
| ... | ... | ... | ... |

---

## 5. 비즈니스 규칙

- {규칙 1}
- {규칙 2}

---

## 6. 관련 파일 (구현 시 생성/수정 대상)

```
src/
├── {module-name}/
│   ├── {module-name}.module.ts
│   ├── {module-name}.controller.ts
│   ├── {module-name}.service.ts
│   └── dto/
│       └── {module-name}.dto.ts
├── database/
│   ├── produce_entity/
│   │   └── {entity-name}.entity.ts
│   └── migrations/
│       └── <timestamp>-create-{table-name}.ts
└── app.module.ts
```
