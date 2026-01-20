---
name: rust-web-apis
description: Building web services, HTTP APIs, and backend systems in Rust. Use when implementing REST/GraphQL APIs, database access, request handling, middleware, or observability.
---

# Rust Web APIs

This document covers building production web services in Rust using Axum, Tower, SQLx, SeaORM, and observability tools. All examples use **Axum 0.8+** syntax.

## 1. Axum Fundamentals

### Basic Application Setup

```rust
use axum::{
    routing::{get, post},
    Router,
};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() {
    // Build the router
    let app = Router::new()
        .route("/", get(root))
        .route("/users", post(create_user))
        .route("/users/{id}", get(get_user));  // Note: {id} syntax in Axum 0.8+

    // Bind and serve
    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("Listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}

async fn root() -> &'static str {
    "Hello, World!"
}
```

### Handler Patterns

Handlers are async functions that take extractors and return something implementing `IntoResponse`:

```rust
use axum::{
    extract::{Path, Query, State, Json},
    response::IntoResponse,
    http::StatusCode,
};
use serde::{Deserialize, Serialize};

// Simple handler - returns a string
async fn hello() -> &'static str {
    "Hello"
}

// Handler with extractors
async fn get_user(Path(id): Path<u64>) -> String {
    format!("User {id}")
}

// Handler returning JSON
#[derive(Serialize)]
struct User { id: u64, name: String }

async fn get_user_json(Path(id): Path<u64>) -> Json<User> {
    Json(User { id, name: "Alice".to_string() })
}

// Handler with status code
async fn create_user(Json(payload): Json<CreateUser>) -> (StatusCode, Json<User>) {
    let user = User { id: 1, name: payload.name };
    (StatusCode::CREATED, Json(user))
}

#[derive(Deserialize)]
struct CreateUser { name: String }
```

### Routing

#### Path Parameters (Axum 0.8+ Syntax)

```rust
// IMPORTANT: Axum 0.8 uses {param} syntax, NOT :param

// Single parameter
.route("/users/{id}", get(get_user))

// Multiple parameters
.route("/orgs/{org}/repos/{repo}", get(get_repo))

// Wildcard (catch-all)
.route("/files/{*path}", get(serve_file))  // {*path} for wildcards

// Escape literal braces
.route("/literal/{{braces}}", get(handler))
```

#### Route Grouping with `nest`

```rust
let user_routes = Router::new()
    .route("/", get(list_users).post(create_user))
    .route("/{id}", get(get_user).put(update_user).delete(delete_user));

let api_routes = Router::new()
    .nest("/users", user_routes)
    .nest("/posts", post_routes);

let app = Router::new()
    .nest("/api/v1", api_routes)
    .route("/health", get(health_check));
```

#### Fallback Handlers

```rust
use axum::handler::HandlerWithoutStateExt;

async fn fallback() -> (StatusCode, &'static str) {
    (StatusCode::NOT_FOUND, "Not Found")
}

let app = Router::new()
    .route("/", get(root))
    .fallback(fallback);
```

### Application State

```rust
use axum::extract::State;
use std::sync::Arc;

// State must be Clone
#[derive(Clone)]
struct AppState {
    db: sqlx::PgPool,
    config: Arc<Config>,
}

struct Config {
    api_key: String,
}

async fn handler(State(state): State<AppState>) -> String {
    // Access state.db, state.config, etc.
    format!("API key length: {}", state.config.api_key.len())
}

#[tokio::main]
async fn main() {
    let state = AppState {
        db: create_pool().await,
        config: Arc::new(Config { api_key: "secret".to_string() }),
    };

    let app = Router::new()
        .route("/", get(handler))
        .with_state(state);

    // ...
}
```

#### State Composition

For different state types on different routes:

```rust
#[derive(Clone)]
struct ApiState { db: PgPool }

#[derive(Clone)]
struct AdminState { admin_db: PgPool }

let api_routes = Router::new()
    .route("/users", get(list_users))
    .with_state(ApiState { db: pool.clone() });

let admin_routes = Router::new()
    .route("/stats", get(get_stats))
    .with_state(AdminState { admin_db: pool });

let app = Router::new()
    .nest("/api", api_routes)
    .nest("/admin", admin_routes);
```

## 2. Extractors Deep Dive

Extractors pull data from requests. Order matters: body-consuming extractors must come last.

### Built-in Extractors

```rust
use axum::{
    extract::{Path, Query, Json, State, Form},
    http::HeaderMap,
};
use serde::Deserialize;

// Path - URL parameters
async fn get_user(Path(id): Path<u64>) -> String {
    format!("User {id}")
}

// Multiple path parameters
async fn get_repo(Path((org, repo)): Path<(String, String)>) -> String {
    format!("{org}/{repo}")
}

// Query - ?page=1&limit=10
#[derive(Deserialize)]
struct Pagination {
    #[serde(default = "default_page")]
    page: u32,
    #[serde(default = "default_limit")]
    limit: u32,
}
fn default_page() -> u32 { 1 }
fn default_limit() -> u32 { 20 }

async fn list_users(Query(pagination): Query<Pagination>) -> String {
    format!("Page {} with {} items", pagination.page, pagination.limit)
}

// Json - request body (consumes body)
#[derive(Deserialize)]
struct CreateUser { name: String, email: String }

async fn create_user(Json(payload): Json<CreateUser>) -> String {
    format!("Created user: {}", payload.name)
}

// Form - form data (consumes body)
async fn login(Form(creds): Form<LoginForm>) -> String {
    format!("Login attempt for {}", creds.username)
}

#[derive(Deserialize)]
struct LoginForm { username: String, password: String }

// HeaderMap - all headers
async fn show_headers(headers: HeaderMap) -> String {
    headers.iter()
        .map(|(k, v)| format!("{}: {:?}", k, v))
        .collect::<Vec<_>>()
        .join("\n")
}

// State - application state (covered above)
async fn with_state(State(state): State<AppState>) -> String {
    // ...
}
```

### Extractor Ordering

Body-consuming extractors (`Json`, `Form`, `Bytes`, `String`) must come last:

```rust
// CORRECT: State before Json
async fn handler(
    State(state): State<AppState>,
    Path(id): Path<u64>,
    Query(query): Query<Params>,
    Json(body): Json<Payload>,  // Body extractor LAST
) -> impl IntoResponse {
    // ...
}

// WRONG: Json before Path would fail
// async fn handler(Json(body): Json<Payload>, Path(id): Path<u64>) // Don't do this
```

### Optional Extractors

Use `Option<T>` for optional extractors:

```rust
async fn handler(
    // Returns None if header missing, errors if header invalid
    auth: Option<TypedHeader<Authorization<Bearer>>>,
    // Returns None if query param missing
    Query(filter): Query<Option<FilterParams>>,
) -> impl IntoResponse {
    match auth {
        Some(TypedHeader(Authorization(bearer))) => {
            format!("Authenticated with token")
        }
        None => format!("Anonymous request"),
    }
}
```

Use `Result<T, E>` for custom error handling:

```rust
async fn handler(
    result: Result<Json<Payload>, JsonRejection>,
) -> impl IntoResponse {
    match result {
        Ok(Json(payload)) => (StatusCode::OK, format!("Got: {:?}", payload)),
        Err(rejection) => (StatusCode::BAD_REQUEST, rejection.to_string()),
    }
}
```

### Custom Extractors

#### FromRequestParts (doesn't consume body)

```rust
use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
    RequestPartsExt,
};
use axum_extra::{
    headers::{authorization::Bearer, Authorization},
    TypedHeader,
};

struct AuthUser {
    user_id: u64,
    role: String,
}

#[async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        // Extract bearer token
        let TypedHeader(Authorization(bearer)) = parts
            .extract::<TypedHeader<Authorization<Bearer>>>()
            .await
            .map_err(|_| AuthError::MissingToken)?;

        // Validate token and get user
        let user = validate_token(bearer.token())
            .await
            .map_err(|_| AuthError::InvalidToken)?;

        Ok(user)
    }
}

#[derive(Debug)]
enum AuthError {
    MissingToken,
    InvalidToken,
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AuthError::MissingToken => (StatusCode::UNAUTHORIZED, "Missing token"),
            AuthError::InvalidToken => (StatusCode::UNAUTHORIZED, "Invalid token"),
        };
        (status, message).into_response()
    }
}

// Use in handlers
async fn protected(user: AuthUser) -> String {
    format!("Hello user {}!", user.user_id)
}
```

#### FromRequest (can consume body)

```rust
use axum::{
    async_trait,
    body::Bytes,
    extract::{FromRequest, Request},
};

struct ValidatedJson<T>(T);

#[async_trait]
impl<S, T> FromRequest<S> for ValidatedJson<T>
where
    S: Send + Sync,
    T: serde::de::DeserializeOwned + Validate,
{
    type Rejection = (StatusCode, String);

    async fn from_request(req: Request, state: &S) -> Result<Self, Self::Rejection> {
        let Json(value) = Json::<T>::from_request(req, state)
            .await
            .map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;

        value.validate()
            .map_err(|e| (StatusCode::UNPROCESSABLE_ENTITY, e.to_string()))?;

        Ok(ValidatedJson(value))
    }
}

trait Validate {
    fn validate(&self) -> Result<(), String>;
}
```

## 3. Response Types

### IntoResponse Trait

Anything implementing `IntoResponse` can be returned from handlers:

```rust
use axum::response::{IntoResponse, Response, Html};
use axum::http::StatusCode;

// Built-in implementations
async fn string_response() -> String { "Hello".to_string() }
async fn str_response() -> &'static str { "Hello" }
async fn html_response() -> Html<&'static str> { Html("<h1>Hello</h1>") }
async fn bytes_response() -> Vec<u8> { vec![72, 101, 108, 108, 111] }

// Tuple responses: (StatusCode, headers, body)
async fn tuple_response() -> (StatusCode, [(&'static str, &'static str); 1], String) {
    (
        StatusCode::CREATED,
        [("X-Custom-Header", "value")],
        "Created".to_string(),
    )
}

// Simple status + body
async fn status_response() -> (StatusCode, &'static str) {
    (StatusCode::NOT_FOUND, "Not found")
}
```

### JSON Responses

```rust
use axum::Json;
use serde::Serialize;

#[derive(Serialize)]
struct ApiResponse<T> {
    data: T,
    #[serde(skip_serializing_if = "Option::is_none")]
    message: Option<String>,
}

async fn json_response() -> Json<ApiResponse<User>> {
    Json(ApiResponse {
        data: User { id: 1, name: "Alice".to_string() },
        message: None,
    })
}

// With status code
async fn json_with_status() -> (StatusCode, Json<ApiResponse<User>>) {
    (StatusCode::CREATED, Json(ApiResponse {
        data: User { id: 1, name: "Alice".to_string() },
        message: Some("User created".to_string()),
    }))
}
```

### Custom Response Types

```rust
use axum::{
    response::{IntoResponse, Response},
    http::StatusCode,
    Json,
};
use serde::Serialize;

#[derive(Serialize)]
struct ApiSuccess<T: Serialize> {
    success: bool,
    data: T,
}

#[derive(Serialize)]
struct ApiError {
    success: bool,
    error: String,
    code: String,
}

enum ApiResponse<T: Serialize> {
    Success(T),
    Error { status: StatusCode, code: String, message: String },
}

impl<T: Serialize> IntoResponse for ApiResponse<T> {
    fn into_response(self) -> Response {
        match self {
            ApiResponse::Success(data) => {
                Json(ApiSuccess { success: true, data }).into_response()
            }
            ApiResponse::Error { status, code, message } => {
                (status, Json(ApiError {
                    success: false,
                    error: message,
                    code,
                })).into_response()
            }
        }
    }
}
```

## 4. Error Handling in Axum

### Error Type Design

```rust
use axum::{
    response::{IntoResponse, Response},
    http::StatusCode,
    Json,
};
use serde_json::json;

// Simple wrapper around anyhow::Error
struct AppError(anyhow::Error);

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        tracing::error!("{:#}", self.0);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "error": "Internal server error" })),
        ).into_response()
    }
}

// Allow using ? with any error type
impl<E: Into<anyhow::Error>> From<E> for AppError {
    fn from(err: E) -> Self {
        AppError(err.into())
    }
}

// Handlers can now use ? freely
async fn handler(State(state): State<AppState>) -> Result<Json<User>, AppError> {
    let user = sqlx::query_as!(User, "SELECT * FROM users WHERE id = $1", 1)
        .fetch_one(&state.db)
        .await?;  // ? works automatically
    Ok(Json(user))
}
```

### Structured Error Types

For more control, define specific error types:

```rust
use axum::{
    response::{IntoResponse, Response},
    http::StatusCode,
    Json,
};
use serde_json::json;

#[derive(Debug)]
enum ApiError {
    NotFound(String),
    BadRequest(String),
    Unauthorized,
    Forbidden,
    Conflict(String),
    Internal(anyhow::Error),
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, code, message) = match self {
            ApiError::NotFound(msg) => (StatusCode::NOT_FOUND, "NOT_FOUND", msg),
            ApiError::BadRequest(msg) => (StatusCode::BAD_REQUEST, "BAD_REQUEST", msg),
            ApiError::Unauthorized => (StatusCode::UNAUTHORIZED, "UNAUTHORIZED", "Unauthorized".to_string()),
            ApiError::Forbidden => (StatusCode::FORBIDDEN, "FORBIDDEN", "Forbidden".to_string()),
            ApiError::Conflict(msg) => (StatusCode::CONFLICT, "CONFLICT", msg),
            ApiError::Internal(err) => {
                tracing::error!("Internal error: {:#}", err);
                (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "Internal server error".to_string())
            }
        };

        (status, Json(json!({
            "error": {
                "code": code,
                "message": message,
            }
        }))).into_response()
    }
}

// Convenience conversions
impl From<sqlx::Error> for ApiError {
    fn from(err: sqlx::Error) -> Self {
        match err {
            sqlx::Error::RowNotFound => ApiError::NotFound("Resource not found".to_string()),
            _ => ApiError::Internal(err.into()),
        }
    }
}
```

See `rust-architecture-patterns.md` for layered error handling patterns.

## 5. Tower Middleware

Axum is built on Tower, using the `Service` and `Layer` abstractions.

### ServiceBuilder Pattern

```rust
use axum::Router;
use tower::ServiceBuilder;
use tower_http::{
    trace::TraceLayer,
    compression::CompressionLayer,
    cors::CorsLayer,
    timeout::TimeoutLayer,
    limit::RequestBodyLimitLayer,
};
use std::time::Duration;

let middleware = ServiceBuilder::new()
    // Layers execute bottom-to-top for requests, top-to-bottom for responses
    .layer(TraceLayer::new_for_http())
    .layer(CompressionLayer::new())
    .layer(CorsLayer::permissive())
    .layer(TimeoutLayer::new(Duration::from_secs(30)))
    .layer(RequestBodyLimitLayer::new(1024 * 1024));  // 1MB limit

let app = Router::new()
    .route("/", get(handler))
    .layer(middleware);
```

### Essential Middleware

#### TraceLayer (Request Tracing)

```rust
use tower_http::trace::{TraceLayer, DefaultOnRequest, DefaultOnResponse};
use tracing::Level;

let trace_layer = TraceLayer::new_for_http()
    .on_request(DefaultOnRequest::new().level(Level::INFO))
    .on_response(DefaultOnResponse::new().level(Level::INFO));
```

#### CorsLayer

```rust
use tower_http::cors::{CorsLayer, Any};
use http::Method;

// Permissive (development)
let cors = CorsLayer::permissive();

// Production configuration
let cors = CorsLayer::new()
    .allow_origin(["https://example.com".parse().unwrap()])
    .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
    .allow_headers(Any)
    .max_age(Duration::from_secs(3600));
```

#### Other Common Layers

```rust
use tower_http::{
    compression::CompressionLayer,
    timeout::TimeoutLayer,
    limit::RequestBodyLimitLayer,
    request_id::{SetRequestIdLayer, PropagateRequestIdLayer, MakeRequestUuid},
};

let app = Router::new()
    .route("/", get(handler))
    .layer(CompressionLayer::new())  // Gzip/deflate responses
    .layer(TimeoutLayer::new(Duration::from_secs(30)))
    .layer(RequestBodyLimitLayer::new(5 * 1024 * 1024))  // 5MB
    .layer(SetRequestIdLayer::x_request_id(MakeRequestUuid))
    .layer(PropagateRequestIdLayer::x_request_id());
```

### Middleware Ordering

Layers wrap services: outermost layer runs first for requests, last for responses.

```rust
Router::new()
    .route("/", get(handler))
    .layer(A)  // Runs 3rd for request, 1st for response
    .layer(B)  // Runs 2nd for request, 2nd for response
    .layer(C)  // Runs 1st for request, 3rd for response

// Request flow:  C -> B -> A -> handler
// Response flow: A -> B -> C -> client
```

### Custom Middleware

#### Using `from_fn`

```rust
use axum::{
    middleware::{self, Next},
    extract::Request,
    response::Response,
};

async fn logging_middleware(request: Request, next: Next) -> Response {
    let method = request.method().clone();
    let uri = request.uri().clone();
    let start = std::time::Instant::now();

    let response = next.run(request).await;

    tracing::info!(
        method = %method,
        uri = %uri,
        status = %response.status(),
        duration_ms = %start.elapsed().as_millis(),
        "Request completed"
    );

    response
}

let app = Router::new()
    .route("/", get(handler))
    .layer(middleware::from_fn(logging_middleware));
```

#### With State

```rust
async fn auth_middleware(
    State(state): State<AppState>,
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let token = request.headers()
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    if !validate_token(&state, token).await {
        return Err(StatusCode::UNAUTHORIZED);
    }

    Ok(next.run(request).await)
}

let app = Router::new()
    .route("/protected", get(protected_handler))
    .layer(middleware::from_fn_with_state(state.clone(), auth_middleware))
    .with_state(state);
```

## 6. Production Patterns

### Graceful Shutdown

Essential for Kubernetes deployments and zero-downtime updates:

```rust
use axum::{routing::get, Router};
use tokio::net::TcpListener;
use tokio::signal;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(|| async { "Hello, World!" }))
        .route("/health", get(|| async { "OK" }));

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    tracing::info!("Server listening on {}", listener.local_addr().unwrap());

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();

    tracing::info!("Server shutdown complete");
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("Failed to install SIGTERM handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => tracing::info!("Received Ctrl+C"),
        _ = terminate => tracing::info!("Received SIGTERM"),
    }
}
```

#### With Resource Cleanup

```rust
use tokio_util::sync::CancellationToken;
use std::sync::Arc;
use std::time::Duration;

struct AppState {
    db_pool: sqlx::PgPool,
    cancel_token: CancellationToken,
}

#[tokio::main]
async fn main() {
    let cancel_token = CancellationToken::new();

    let db_pool = sqlx::PgPool::connect(&std::env::var("DATABASE_URL").unwrap())
        .await
        .unwrap();

    let state = Arc::new(AppState {
        db_pool: db_pool.clone(),
        cancel_token: cancel_token.clone(),
    });

    // Spawn background tasks
    let bg_token = cancel_token.clone();
    let bg_handle = tokio::spawn(async move {
        background_worker(bg_token).await;
    });

    let app = Router::new()
        .route("/", get(root_handler))
        .with_state(state);

    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();

    axum::serve(listener, app)
        .with_graceful_shutdown(async move {
            shutdown_signal().await;
            cancel_token.cancel();
        })
        .await
        .unwrap();

    // Wait for background tasks (with timeout)
    let _ = tokio::time::timeout(Duration::from_secs(30), bg_handle).await;

    // Close database connections gracefully
    db_pool.close().await;

    tracing::info!("Cleanup complete");
}

async fn background_worker(token: CancellationToken) {
    loop {
        tokio::select! {
            _ = token.cancelled() => {
                tracing::info!("Background worker shutting down");
                break;
            }
            _ = tokio::time::sleep(Duration::from_secs(60)) => {
                tracing::debug!("Background tick");
            }
        }
    }
}
```

### Health Checks (Kubernetes)

Implement liveness, readiness, and startup probes:

```rust
use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use serde::Serialize;
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone)]
struct AppState {
    db_pool: sqlx::PgPool,
    ready: Arc<RwLock<bool>>,
}

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    details: Option<HealthDetails>,
}

#[derive(Serialize)]
struct HealthDetails {
    database: &'static str,
}

/// Liveness probe - is the process alive?
/// Keep it simple and fast, avoid external dependencies
async fn liveness() -> impl IntoResponse {
    Json(HealthResponse {
        status: "ok",
        details: None,
    })
}

/// Readiness probe - can the service handle traffic?
/// Check all dependencies
async fn readiness(State(state): State<AppState>) -> impl IntoResponse {
    if !*state.ready.read().await {
        return (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(HealthResponse {
                status: "not_ready",
                details: None,
            }),
        );
    }

    let db_healthy = sqlx::query("SELECT 1")
        .fetch_one(&state.db_pool)
        .await
        .is_ok();

    if db_healthy {
        (
            StatusCode::OK,
            Json(HealthResponse {
                status: "ok",
                details: Some(HealthDetails { database: "connected" }),
            }),
        )
    } else {
        (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(HealthResponse {
                status: "unhealthy",
                details: Some(HealthDetails { database: "disconnected" }),
            }),
        )
    }
}

/// Startup probe - has the application started?
async fn startup(State(state): State<AppState>) -> impl IntoResponse {
    if *state.ready.read().await {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    }
}

fn health_routes() -> Router<AppState> {
    Router::new()
        .route("/health/live", get(liveness))
        .route("/health/ready", get(readiness))
        .route("/health/startup", get(startup))
}
```

Kubernetes deployment configuration:

```yaml
spec:
  containers:
    - name: app
      livenessProbe:
        httpGet:
          path: /health/live
          port: 3000
        initialDelaySeconds: 5
        periodSeconds: 10
      readinessProbe:
        httpGet:
          path: /health/ready
          port: 3000
        initialDelaySeconds: 5
        periodSeconds: 5
      startupProbe:
        httpGet:
          path: /health/startup
          port: 3000
        failureThreshold: 30
        periodSeconds: 2
  terminationGracePeriodSeconds: 30
```

### WebSockets

Add `ws` feature to Axum:

```toml
[dependencies]
axum = { version = "0.8", features = ["ws"] }
futures-util = "0.3"
```

#### Basic Echo Server

```rust
use axum::{
    extract::ws::{Message, WebSocket, WebSocketUpgrade},
    response::IntoResponse,
    routing::get,
    Router,
};
use futures_util::{SinkExt, StreamExt};

async fn ws_handler(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(mut socket: WebSocket) {
    while let Some(msg) = socket.recv().await {
        let msg = match msg {
            Ok(msg) => msg,
            Err(e) => {
                tracing::error!("WebSocket error: {}", e);
                break;
            }
        };

        match msg {
            Message::Text(text) => {
                if socket.send(Message::Text(format!("Echo: {}", text))).await.is_err() {
                    break;
                }
            }
            Message::Binary(data) => {
                if socket.send(Message::Binary(data)).await.is_err() {
                    break;
                }
            }
            Message::Close(_) => break,
            _ => {} // Ping/Pong handled automatically
        }
    }
}
```

#### Chat Room with Broadcast

```rust
use axum::{
    extract::{ws::{Message, WebSocket, WebSocketUpgrade}, State},
    response::IntoResponse,
    routing::get,
    Router,
};
use futures_util::{SinkExt, StreamExt};
use tokio::sync::broadcast;

#[derive(Clone)]
struct ChatState {
    tx: broadcast::Sender<String>,
}

async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<ChatState>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: ChatState) {
    let (mut sender, mut receiver) = socket.split();
    let mut rx = state.tx.subscribe();

    // Forward broadcast messages to this client
    let mut send_task = tokio::spawn(async move {
        while let Ok(msg) = rx.recv().await {
            if sender.send(Message::Text(msg)).await.is_err() {
                break;
            }
        }
    });

    // Receive from client and broadcast
    let tx = state.tx.clone();
    let mut recv_task = tokio::spawn(async move {
        while let Some(Ok(Message::Text(text))) = receiver.next().await {
            let _ = tx.send(text);
        }
    });

    tokio::select! {
        _ = &mut send_task => recv_task.abort(),
        _ = &mut recv_task => send_task.abort(),
    }
}

#[tokio::main]
async fn main() {
    let (tx, _rx) = broadcast::channel(100);
    let state = ChatState { tx };

    let app = Router::new()
        .route("/ws", get(ws_handler))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

### Server-Sent Events (SSE)

One-way server-to-client streaming, simpler than WebSockets:

```rust
use axum::{
    response::sse::{Event, KeepAlive, Sse},
    routing::get,
    Router,
};
use futures_util::stream::{self, Stream};
use std::{convert::Infallible, time::Duration};
use tokio_stream::StreamExt;

async fn sse_handler() -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let stream = stream::repeat_with(|| {
        Event::default()
            .data("heartbeat")
            .event("ping")
    })
    .map(Ok)
    .throttle(Duration::from_secs(1));

    Sse::new(stream).keep_alive(KeepAlive::default())
}
```

#### Dynamic Events with Channels

```rust
use axum::{
    extract::State,
    response::sse::{Event, KeepAlive, Sse},
    routing::{get, post},
    Json, Router,
};
use async_stream::try_stream;
use futures_util::Stream;
use std::convert::Infallible;
use tokio::sync::broadcast;

#[derive(Clone)]
struct SseState {
    tx: broadcast::Sender<String>,
}

async fn sse_handler(
    State(state): State<SseState>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let mut rx = state.tx.subscribe();

    let stream = try_stream! {
        loop {
            match rx.recv().await {
                Ok(msg) => yield Event::default().data(msg),
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(broadcast::error::RecvError::Closed) => break,
            }
        }
    };

    Sse::new(stream).keep_alive(KeepAlive::default())
}

async fn send_event(
    State(state): State<SseState>,
    Json(message): Json<String>,
) -> &'static str {
    let _ = state.tx.send(message);
    "Event sent"
}
```

## 7. Authentication

### JWT Authentication

```toml
[dependencies]
axum = "0.8"
axum-extra = { version = "0.9", features = ["typed-header"] }
jsonwebtoken = "9"
chrono = { version = "0.4", features = ["serde"] }
once_cell = "1"
```

```rust
use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, RequestPartsExt, Router,
};
use axum_extra::{
    headers::{authorization::Bearer, Authorization},
    TypedHeader,
};
use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};

static KEYS: Lazy<Keys> = Lazy::new(|| {
    let secret = std::env::var("JWT_SECRET").expect("JWT_SECRET must be set");
    Keys::new(secret.as_bytes())
});

struct Keys {
    encoding: EncodingKey,
    decoding: DecodingKey,
}

impl Keys {
    fn new(secret: &[u8]) -> Self {
        Self {
            encoding: EncodingKey::from_secret(secret),
            decoding: DecodingKey::from_secret(secret),
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,      // Subject (user ID)
    pub exp: i64,         // Expiration time
    pub iat: i64,         // Issued at
    pub role: String,     // User role
}

#[derive(Debug)]
pub enum AuthError {
    MissingCredentials,
    InvalidToken,
    ExpiredToken,
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AuthError::MissingCredentials => (StatusCode::UNAUTHORIZED, "Missing credentials"),
            AuthError::InvalidToken => (StatusCode::UNAUTHORIZED, "Invalid token"),
            AuthError::ExpiredToken => (StatusCode::UNAUTHORIZED, "Token expired"),
        };
        (status, Json(serde_json::json!({ "error": message }))).into_response()
    }
}

// Claims extractor
#[async_trait]
impl<S> FromRequestParts<S> for Claims
where
    S: Send + Sync,
{
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let TypedHeader(Authorization(bearer)) = parts
            .extract::<TypedHeader<Authorization<Bearer>>>()
            .await
            .map_err(|_| AuthError::MissingCredentials)?;

        let token_data = decode::<Claims>(
            bearer.token(),
            &KEYS.decoding,
            &Validation::default(),
        )
        .map_err(|e| match e.kind() {
            jsonwebtoken::errors::ErrorKind::ExpiredSignature => AuthError::ExpiredToken,
            _ => AuthError::InvalidToken,
        })?;

        Ok(token_data.claims)
    }
}

// Token creation
pub fn create_token(user_id: &str, role: &str) -> Result<String, jsonwebtoken::errors::Error> {
    let now = Utc::now();
    let expires_in = Duration::hours(24);

    let claims = Claims {
        sub: user_id.to_string(),
        exp: (now + expires_in).timestamp(),
        iat: now.timestamp(),
        role: role.to_string(),
    };

    encode(&Header::default(), &claims, &KEYS.encoding)
}

// Login handler
#[derive(Deserialize)]
struct LoginRequest {
    username: String,
    password: String,
}

#[derive(Serialize)]
struct LoginResponse {
    token: String,
    expires_in: i64,
}

async fn login(Json(payload): Json<LoginRequest>) -> Result<Json<LoginResponse>, AuthError> {
    // Validate credentials (replace with real authentication)
    let user = authenticate(&payload.username, &payload.password)
        .await
        .map_err(|_| AuthError::InvalidToken)?;

    let token = create_token(&user.id, &user.role)
        .map_err(|_| AuthError::InvalidToken)?;

    Ok(Json(LoginResponse {
        token,
        expires_in: 86400, // 24 hours
    }))
}

// Protected handler
async fn protected(claims: Claims) -> impl IntoResponse {
    Json(serde_json::json!({
        "message": format!("Welcome, {}!", claims.sub),
        "role": claims.role,
    }))
}
```

### Auth Middleware Pattern

For route-based authentication:

```rust
use axum::{
    middleware::{self, Next},
    extract::{Request, State},
    response::Response,
    http::StatusCode,
};

async fn require_auth(
    claims: Result<Claims, AuthError>,
    request: Request,
    next: Next,
) -> Result<Response, AuthError> {
    claims?;  // Return error if authentication failed
    Ok(next.run(request).await)
}

async fn require_admin(
    claims: Claims,
    request: Request,
    next: Next,
) -> Result<Response, (StatusCode, &'static str)> {
    if claims.role != "admin" {
        return Err((StatusCode::FORBIDDEN, "Admin access required"));
    }
    Ok(next.run(request).await)
}

// Apply to routes
let app = Router::new()
    .route("/admin", get(admin_handler))
    .layer(middleware::from_fn(require_admin))
    .route("/protected", get(protected_handler))
    .layer(middleware::from_fn(require_auth))
    .route("/public", get(public_handler));
```

## 8. Database: SQLx

SQLx provides compile-time checked queries against your database.

### Connection Setup

```rust
use sqlx::postgres::PgPoolOptions;
use std::time::Duration;

async fn create_pool() -> sqlx::PgPool {
    PgPoolOptions::new()
        .max_connections(20)
        .min_connections(5)
        .acquire_timeout(Duration::from_secs(3))
        .idle_timeout(Duration::from_secs(600))
        .max_lifetime(Duration::from_secs(1800))
        .connect(&std::env::var("DATABASE_URL").expect("DATABASE_URL must be set"))
        .await
        .expect("Failed to create pool")
}
```

### Compile-Time Checked Queries

Requires `DATABASE_URL` environment variable set at compile time:

```rust
use sqlx::FromRow;

#[derive(Debug, FromRow)]
struct User {
    id: i64,
    email: String,
    created_at: chrono::DateTime<chrono::Utc>,
}

// query! - returns anonymous record
async fn get_user_email(pool: &sqlx::PgPool, id: i64) -> Result<String, sqlx::Error> {
    let record = sqlx::query!(
        "SELECT email FROM users WHERE id = $1",
        id
    )
    .fetch_one(pool)
    .await?;

    Ok(record.email)
}

// query_as! - returns typed struct
async fn get_user(pool: &sqlx::PgPool, id: i64) -> Result<User, sqlx::Error> {
    sqlx::query_as!(
        User,
        r#"SELECT id, email, created_at FROM users WHERE id = $1"#,
        id
    )
    .fetch_one(pool)
    .await
}

// Fetch multiple rows
async fn list_users(pool: &sqlx::PgPool, limit: i64) -> Result<Vec<User>, sqlx::Error> {
    sqlx::query_as!(
        User,
        "SELECT id, email, created_at FROM users ORDER BY created_at DESC LIMIT $1",
        limit
    )
    .fetch_all(pool)
    .await
}

// Optional fetch
async fn find_user_by_email(pool: &sqlx::PgPool, email: &str) -> Result<Option<User>, sqlx::Error> {
    sqlx::query_as!(
        User,
        "SELECT id, email, created_at FROM users WHERE email = $1",
        email
    )
    .fetch_optional(pool)
    .await
}
```

### Runtime Queries

Use `query()` instead of `query!()` when the query is dynamic:

```rust
use sqlx::{Row, FromRow};

// When query structure is dynamic
async fn search_users(
    pool: &sqlx::PgPool,
    filter: &str,
    order_by: &str,
) -> Result<Vec<User>, sqlx::Error> {
    // NOTE: Be careful with SQL injection - validate order_by!
    let query = format!(
        "SELECT id, email, created_at FROM users WHERE email LIKE $1 ORDER BY {}",
        order_by
    );

    sqlx::query_as::<_, User>(&query)
        .bind(format!("%{}%", filter))
        .fetch_all(pool)
        .await
}
```

### Transactions

```rust
async fn transfer_credits(
    pool: &sqlx::PgPool,
    from_id: i64,
    to_id: i64,
    amount: i64,
) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query!(
        "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
        amount,
        from_id
    )
    .execute(&mut *tx)
    .await?;

    sqlx::query!(
        "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
        amount,
        to_id
    )
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}
```

### Migrations

Install SQLx CLI:

```bash
cargo install sqlx-cli --no-default-features --features native-tls,postgres
```

Common commands:

```bash
# Create database
sqlx database create

# Create migration (reversible)
sqlx migrate add -r create_users

# Run migrations
sqlx migrate run

# Revert last migration
sqlx migrate revert

# Check status
sqlx migrate info
```

Migration file example (`migrations/20240101000000_create_users.up.sql`):

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
```

Embed migrations in application:

```rust
use sqlx::migrate::Migrator;

static MIGRATOR: Migrator = sqlx::migrate!("./migrations");

async fn run_migrations(pool: &sqlx::PgPool) -> Result<(), sqlx::Error> {
    MIGRATOR.run(pool).await?;
    Ok(())
}
```

### Offline Mode for CI

Generate query metadata:

```bash
cargo sqlx prepare -- --all-targets --all-features
```

This creates `.sqlx/` directory. Commit it to version control.

In CI, build without database:

```bash
SQLX_OFFLINE=true cargo build
```

### Connection Pool Best Practices

| Setting | Purpose | Recommendation |
|---------|---------|----------------|
| `max_connections` | Upper limit | Match expected concurrent queries |
| `min_connections` | Keep warm | 20-50% of max |
| `acquire_timeout` | Wait for connection | 3-5 seconds |
| `idle_timeout` | Close idle connections | 10 minutes |
| `max_lifetime` | Force reconnection | 30 minutes |

## 9. Database: SeaORM

SeaORM provides an async ORM with entity abstraction.

### Entity Definition

```rust
use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "users")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i64,
    #[sea_orm(unique)]
    pub email: String,
    pub password_hash: String,
    pub created_at: DateTimeUtc,
    pub updated_at: DateTimeUtc,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::post::Entity")]
    Posts,
}

impl Related<super::post::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Posts.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
```

### Query Builder

```rust
use sea_orm::*;

// Find by primary key
let user: Option<user::Model> = User::find_by_id(1).one(&db).await?;

// Find with filter
let users: Vec<user::Model> = User::find()
    .filter(user::Column::Email.contains("@example.com"))
    .order_by_desc(user::Column::CreatedAt)
    .limit(10)
    .all(&db)
    .await?;

// Pagination
let paginator = User::find()
    .filter(user::Column::Email.contains("@example.com"))
    .paginate(&db, 20);  // 20 per page

let total_pages = paginator.num_pages().await?;
let page_1: Vec<user::Model> = paginator.fetch_page(0).await?;
```

### Insert/Update/Delete

```rust
use sea_orm::*;

// Insert
let user = user::ActiveModel {
    email: Set("user@example.com".to_string()),
    password_hash: Set("hashed".to_string()),
    ..Default::default()
};
let result = user.insert(&db).await?;

// Update
let mut user: user::ActiveModel = User::find_by_id(1)
    .one(&db)
    .await?
    .unwrap()
    .into();
user.email = Set("new@example.com".to_string());
let updated = user.update(&db).await?;

// Delete
let user = User::find_by_id(1).one(&db).await?.unwrap();
user.delete(&db).await?;

// Bulk insert
let users = vec![
    user::ActiveModel { email: Set("a@example.com".to_string()), ..Default::default() },
    user::ActiveModel { email: Set("b@example.com".to_string()), ..Default::default() },
];
User::insert_many(users).exec(&db).await?;
```

### SQLx vs SeaORM Decision

| Factor | SQLx | SeaORM |
|--------|------|--------|
| **Query style** | Raw SQL | Query builder |
| **Type safety** | Compile-time checked | Runtime |
| **Flexibility** | Full SQL control | ORM abstractions |
| **Performance** | Minimal overhead | Small overhead |
| **Complex queries** | Natural | Can be verbose |
| **Migrations** | Built-in CLI | Separate tool |

**Use SQLx when:**
- You need complex SQL queries
- Performance is critical
- Team is comfortable with SQL
- You want compile-time query checking

**Use SeaORM when:**
- You prefer ORM patterns
- Building CRUD-heavy applications
- You want entity relationships managed
- Team prefers query builder syntax

## 10. Serialization with Serde

### Common Attributes

```rust
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]  // user_id -> userId
pub struct User {
    pub user_id: u64,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub middle_name: Option<String>,

    #[serde(default)]  // Use Default if missing
    pub role: Role,

    #[serde(with = "chrono::serde::ts_seconds")]
    pub created_at: chrono::DateTime<chrono::Utc>,

    #[serde(flatten)]  // Inline nested struct fields
    pub metadata: Metadata,

    #[serde(skip)]  // Never serialize
    pub internal_cache: String,

    #[serde(alias = "userName", alias = "user_name")]  // Accept multiple names
    pub username: String,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Role {
    #[default]
    User,
    Admin,
    Moderator,
}

#[derive(Serialize, Deserialize)]
pub struct Metadata {
    pub version: u32,
    pub source: String,
}
```

### Enum Serialization

```rust
use serde::{Deserialize, Serialize};

// Externally tagged (default): {"status": {"Error": {"code": 500}}}
#[derive(Serialize, Deserialize)]
pub enum Status {
    Pending,
    Active,
    Error { code: u32 },
}

// Internally tagged: {"type": "error", "code": 500}
#[derive(Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum Event {
    Created { id: u64 },
    Updated { id: u64, changes: Vec<String> },
    Deleted { id: u64 },
}

// Adjacently tagged: {"t": "error", "c": {"code": 500}}
#[derive(Serialize, Deserialize)]
#[serde(tag = "t", content = "c")]
pub enum Message {
    Request(RequestData),
    Response(ResponseData),
}

// Untagged: tries each variant in order
#[derive(Serialize, Deserialize)]
#[serde(untagged)]
pub enum Value {
    Integer(i64),
    Float(f64),
    String(String),
}
```

### Validation on Deserialization

```rust
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]  // Error on extra fields
pub struct StrictInput {
    pub name: String,
    pub age: u32,
}

// Custom validation
use serde::de::{self, Deserialize, Deserializer};

fn deserialize_non_empty_string<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: Deserializer<'de>,
{
    let s = String::deserialize(deserializer)?;
    if s.is_empty() {
        return Err(de::Error::custom("string cannot be empty"));
    }
    Ok(s)
}

#[derive(Deserialize)]
pub struct ValidatedInput {
    #[serde(deserialize_with = "deserialize_non_empty_string")]
    pub name: String,
}
```

### Zero-Copy Deserialization

Borrow from input to avoid allocations:

```rust
use serde::Deserialize;

#[derive(Deserialize)]
pub struct Document<'a> {
    #[serde(borrow)]
    pub title: &'a str,

    #[serde(borrow)]
    pub tags: Vec<&'a str>,
}

// Usage
let json = r#"{"title": "Hello", "tags": ["a", "b"]}"#;
let doc: Document = serde_json::from_str(json)?;
// doc.title points into json string, no copy

// Only works with from_str, not from_reader
```

## 11. Structured Logging with tracing

### Setup

```rust
use tracing::{info, warn, error, Level};
use tracing_subscriber::{
    layer::SubscriberExt,
    util::SubscriberInitExt,
    fmt,
    EnvFilter,
};

fn init_tracing() {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| EnvFilter::new("info")))
        .with(fmt::layer()
            .json()  // JSON for production
            .with_target(true)
            .with_thread_ids(true))
        .init();
}

// For development, use pretty printing
fn init_tracing_dev() {
    tracing_subscriber::registry()
        .with(EnvFilter::new("debug"))
        .with(fmt::layer().pretty())
        .init();
}
```

### Instrumentation

```rust
use tracing::{instrument, info, debug, Span};

// Automatic span creation
#[instrument(skip(db), fields(user_id))]
async fn get_user(db: &PgPool, user_id: u64) -> Result<User, Error> {
    info!("Fetching user");

    let user = sqlx::query_as!(User, "SELECT * FROM users WHERE id = $1", user_id as i64)
        .fetch_one(db)
        .await?;

    // Add field to current span
    Span::current().record("user_id", user.id);

    info!(email = %user.email, "User found");
    Ok(user)
}

// Skip sensitive fields
#[instrument(skip(password))]
async fn authenticate(username: &str, password: &str) -> Result<User, Error> {
    // ...
}

// Manual span creation
async fn process_batch(items: Vec<Item>) {
    let span = tracing::info_span!("process_batch", count = items.len());
    let _guard = span.enter();

    for item in items {
        debug!(item_id = %item.id, "Processing item");
        // ...
    }
}
```

### Log Levels

```rust
use tracing::{trace, debug, info, warn, error};

// Structured fields
info!(
    user_id = %user.id,
    action = "login",
    ip = %request.ip(),
    "User logged in"
);

// Levels and when to use them
trace!("Very detailed debugging info");
debug!("Debugging info for development");
info!("Normal operational messages");
warn!("Something unexpected but handled");
error!("Error that needs attention");

// Error with error chain
error!(
    error = ?err,  // Debug format
    "Failed to process request"
);
```

### Axum Integration

```rust
use tower_http::trace::{TraceLayer, DefaultMakeSpan, DefaultOnResponse};
use tracing::Level;

let app = Router::new()
    .route("/", get(handler))
    .layer(
        TraceLayer::new_for_http()
            .make_span_with(DefaultMakeSpan::new().level(Level::INFO))
            .on_response(DefaultOnResponse::new().level(Level::INFO))
    );
```

## 12. OpenTelemetry Integration

### Dependencies

```toml
[dependencies]
opentelemetry = "0.31"
opentelemetry_sdk = { version = "0.31", features = ["rt-tokio"] }
opentelemetry-otlp = { version = "0.31", features = ["tonic"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
tracing-opentelemetry = "0.31"
```

### OTLP Setup

```rust
use opentelemetry::trace::TracerProvider;
use opentelemetry_sdk::{
    runtime,
    trace::{SdkTracerProvider, Config as TraceConfig},
    Resource,
};
use opentelemetry_otlp::SpanExporter;
use opentelemetry::KeyValue;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

async fn init_telemetry() -> Result<(), Box<dyn std::error::Error>> {
    // Resource with service info
    let resource = Resource::builder()
        .with_attributes([
            KeyValue::new("service.name", "my-service"),
            KeyValue::new("service.version", env!("CARGO_PKG_VERSION")),
            KeyValue::new("deployment.environment", "production"),
        ])
        .build();

    // Build tracer provider
    let tracer_provider = SdkTracerProvider::builder()
        .with_resource(resource)
        .with_batch_exporter(
            SpanExporter::builder()
                .with_tonic()
                .with_endpoint("http://localhost:4317")
                .build()?,
        )
        .build();

    let tracer = tracer_provider.tracer("my-service");

    // Combine with tracing
    let otel_layer = tracing_opentelemetry::layer().with_tracer(tracer);

    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .with(tracing_subscriber::fmt::layer())
        .with(otel_layer)
        .init();

    Ok(())
}
```

### Context Propagation

Extract trace ID for logging:

```rust
use opentelemetry::trace::TraceContextExt;
use tracing_opentelemetry::OpenTelemetrySpanExt;

fn get_trace_id() -> String {
    let context = tracing::Span::current().context();
    let span = context.span();
    let span_context = span.span_context();
    span_context.trace_id().to_string()
}

// Include in error responses
async fn handler() -> Result<Json<Data>, (StatusCode, Json<ErrorResponse>)> {
    match do_work().await {
        Ok(data) => Ok(Json(data)),
        Err(e) => {
            let trace_id = get_trace_id();
            Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: "Internal error".to_string(),
                    trace_id,
                }),
            ))
        }
    }
}
```

## 13. Prometheus Metrics

### Metric Types

```rust
use prometheus::{Counter, CounterVec, Gauge, Histogram, HistogramOpts, Opts, Registry};
use lazy_static::lazy_static;

lazy_static! {
    static ref REGISTRY: Registry = Registry::new();

    // Counter - monotonically increasing
    static ref HTTP_REQUESTS_TOTAL: CounterVec = CounterVec::new(
        Opts::new("http_requests_total", "Total HTTP requests"),
        &["method", "path", "status"]
    ).unwrap();

    // Gauge - can go up and down
    static ref HTTP_REQUESTS_IN_FLIGHT: Gauge = Gauge::new(
        "http_requests_in_flight",
        "Current number of in-flight requests"
    ).unwrap();

    // Histogram - distribution of values
    static ref HTTP_REQUEST_DURATION: Histogram = Histogram::with_opts(
        HistogramOpts::new("http_request_duration_seconds", "Request duration")
            .buckets(vec![0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0])
    ).unwrap();
}

fn init_metrics() {
    REGISTRY.register(Box::new(HTTP_REQUESTS_TOTAL.clone())).unwrap();
    REGISTRY.register(Box::new(HTTP_REQUESTS_IN_FLIGHT.clone())).unwrap();
    REGISTRY.register(Box::new(HTTP_REQUEST_DURATION.clone())).unwrap();
}
```

### Instrumentation

```rust
use axum::{
    middleware::{self, Next},
    extract::Request,
    response::Response,
};

async fn metrics_middleware(request: Request, next: Next) -> Response {
    let method = request.method().to_string();
    let path = request.uri().path().to_string();
    let start = std::time::Instant::now();

    HTTP_REQUESTS_IN_FLIGHT.inc();

    let response = next.run(request).await;

    HTTP_REQUESTS_IN_FLIGHT.dec();

    let duration = start.elapsed().as_secs_f64();
    let status = response.status().as_u16().to_string();

    HTTP_REQUESTS_TOTAL
        .with_label_values(&[&method, &path, &status])
        .inc();

    HTTP_REQUEST_DURATION.observe(duration);

    response
}
```

### Metrics Endpoint

```rust
use prometheus::Encoder;

async fn metrics_handler() -> String {
    let encoder = prometheus::TextEncoder::new();
    let mut buffer = Vec::new();
    encoder.encode(&REGISTRY.gather(), &mut buffer).unwrap();
    String::from_utf8(buffer).unwrap()
}

let app = Router::new()
    .route("/api/users", get(list_users))
    .route("/metrics", get(metrics_handler))
    .layer(middleware::from_fn(metrics_middleware));
```

### Essential Metrics

Every service should expose:

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `http_requests_total` | Counter | method, path, status | Total requests |
| `http_request_duration_seconds` | Histogram | method, path | Request latency |
| `http_requests_in_flight` | Gauge | | Current requests |
| `db_query_duration_seconds` | Histogram | query_type | Database latency |
| `db_connections_active` | Gauge | | Active DB connections |
| `errors_total` | Counter | type | Error count by type |

## 14. gRPC with Tonic

### Dependencies

```toml
[dependencies]
tonic = "0.14"
prost = "0.13"
tokio = { version = "1", features = ["macros", "rt-multi-thread"] }
tokio-stream = "0.1"

[build-dependencies]
tonic-build = "0.14"
```

### Proto Definition

```protobuf
// proto/hello.proto
syntax = "proto3";

package hello;

service Greeter {
    rpc SayHello (HelloRequest) returns (HelloResponse);
    rpc SayHelloStream (HelloRequest) returns (stream HelloResponse);
}

message HelloRequest {
    string name = 1;
}

message HelloResponse {
    string message = 1;
}
```

### Build Script

```rust
// build.rs
fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::compile_protos("proto/hello.proto")?;
    Ok(())
}
```

### Server Implementation

```rust
use tonic::{transport::Server, Request, Response, Status};

pub mod hello {
    tonic::include_proto!("hello");
}

use hello::{
    greeter_server::{Greeter, GreeterServer},
    HelloRequest, HelloResponse,
};

#[derive(Debug, Default)]
pub struct MyGreeter {}

#[tonic::async_trait]
impl Greeter for MyGreeter {
    async fn say_hello(
        &self,
        request: Request<HelloRequest>,
    ) -> Result<Response<HelloResponse>, Status> {
        let name = request.into_inner().name;
        Ok(Response::new(HelloResponse {
            message: format!("Hello, {}!", name),
        }))
    }

    type SayHelloStreamStream =
        tokio_stream::wrappers::ReceiverStream<Result<HelloResponse, Status>>;

    async fn say_hello_stream(
        &self,
        request: Request<HelloRequest>,
    ) -> Result<Response<Self::SayHelloStreamStream>, Status> {
        let name = request.into_inner().name;
        let (tx, rx) = tokio::sync::mpsc::channel(4);

        tokio::spawn(async move {
            for i in 0..5 {
                let response = HelloResponse {
                    message: format!("Hello {} - message {}", name, i),
                };
                if tx.send(Ok(response)).await.is_err() {
                    break;
                }
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
            }
        });

        Ok(Response::new(tokio_stream::wrappers::ReceiverStream::new(rx)))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr = "[::1]:50051".parse()?;
    let greeter = MyGreeter::default();

    Server::builder()
        .add_service(GreeterServer::new(greeter))
        .serve(addr)
        .await?;

    Ok(())
}
```

### Client Implementation

```rust
use hello::greeter_client::GreeterClient;
use hello::HelloRequest;

pub mod hello {
    tonic::include_proto!("hello");
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut client = GreeterClient::connect("http://[::1]:50051").await?;

    let request = tonic::Request::new(HelloRequest {
        name: "World".into(),
    });

    let response = client.say_hello(request).await?;
    println!("Response: {:?}", response);

    Ok(())
}
```

## 15. Full Stack Example

Complete Axum application with SQLx, tracing, and metrics:

```rust
use axum::{
    extract::{Path, State, Json},
    routing::{get, post},
    http::StatusCode,
    middleware,
    Router,
};
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgPoolOptions;
use std::sync::Arc;
use std::time::Duration;
use tower_http::trace::TraceLayer;
use tracing::{info, instrument};

// === Types ===

#[derive(Clone)]
struct AppState {
    db: sqlx::PgPool,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
struct User {
    id: i64,
    email: String,
    name: String,
}

#[derive(Debug, Deserialize)]
struct CreateUser {
    email: String,
    name: String,
}

struct AppError(anyhow::Error);

impl axum::response::IntoResponse for AppError {
    fn into_response(self) -> axum::response::Response {
        tracing::error!("{:#}", self.0);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": "Internal server error" })),
        ).into_response()
    }
}

impl<E: Into<anyhow::Error>> From<E> for AppError {
    fn from(err: E) -> Self {
        AppError(err.into())
    }
}

// === Handlers ===

#[instrument(skip(state))]
async fn list_users(State(state): State<AppState>) -> Result<Json<Vec<User>>, AppError> {
    let users = sqlx::query_as!(User, "SELECT id, email, name FROM users")
        .fetch_all(&state.db)
        .await?;
    Ok(Json(users))
}

#[instrument(skip(state))]
async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<User>, AppError> {
    let user = sqlx::query_as!(User, "SELECT id, email, name FROM users WHERE id = $1", id)
        .fetch_one(&state.db)
        .await?;
    Ok(Json(user))
}

#[instrument(skip(state, payload))]
async fn create_user(
    State(state): State<AppState>,
    Json(payload): Json<CreateUser>,
) -> Result<(StatusCode, Json<User>), AppError> {
    let user = sqlx::query_as!(
        User,
        "INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id, email, name",
        payload.email,
        payload.name
    )
    .fetch_one(&state.db)
    .await?;

    info!(user_id = user.id, "Created user");
    Ok((StatusCode::CREATED, Json(user)))
}

async fn health() -> &'static str {
    "OK"
}

// === Main ===

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .json()
        .init();

    // Create database pool
    let db = PgPoolOptions::new()
        .max_connections(20)
        .acquire_timeout(Duration::from_secs(3))
        .connect(&std::env::var("DATABASE_URL")?)
        .await?;

    // Run migrations
    sqlx::migrate!("./migrations").run(&db).await?;

    let state = AppState { db };

    // Build router
    let app = Router::new()
        .route("/health", get(health))
        .route("/users", get(list_users).post(create_user))
        .route("/users/{id}", get(get_user))
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    // Start server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    info!("Server listening on {}", listener.local_addr()?);

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}

async fn shutdown_signal() {
    tokio::signal::ctrl_c()
        .await
        .expect("Failed to install Ctrl+C handler");
    info!("Shutdown signal received");
}
```

### Cargo.toml for Full Example

```toml
[package]
name = "my-api"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = { version = "0.8", features = ["json"] }
tokio = { version = "1", features = ["full"] }
tower-http = { version = "0.6", features = ["trace"] }
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "chrono"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
anyhow = "1"
chrono = { version = "0.4", features = ["serde"] }
```

## See Also

- `rust-architecture-patterns.md` - Layered error handling and application structure
- `rust-implementation-patterns.md` - Async patterns and concurrency
- `rust-testing-quality.md` - Testing web APIs
