---
name: rust-cli-desktop-systems
description: Building command-line tools, terminal UIs, desktop applications, embedded systems, and low-level system integrations in Rust. Use when creating CLIs, TUI dashboards, cross-platform desktop apps, embedded firmware, FFI bindings, or WebAssembly modules.
---

# CLI, Desktop, and Systems Development in Rust

This guide covers building user-facing applications and low-level system integrations: command-line tools, terminal UIs, desktop applications, embedded firmware, foreign function interfaces, WebAssembly modules, and Rust macros.

## 1. CLI Applications with Clap

Clap is the standard library for command-line argument parsing in Rust. The derive-based API provides type-safe, declarative argument definitions.

### Derive-Based Setup

```rust
use clap::{Parser, Subcommand, Args};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "myapp")]
#[command(version, about, long_about = None)]
struct Cli {
    /// Enable verbose output
    #[arg(short, long, global = true)]
    verbose: bool,

    /// Configuration file path
    #[arg(short, long, env = "MYAPP_CONFIG")]
    config: Option<PathBuf>,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize a new project
    Init {
        /// Project directory
        #[arg(default_value = ".")]
        path: PathBuf,

        /// Project template to use
        #[arg(short, long, default_value = "default")]
        template: String,
    },

    /// Run the development server
    Serve(ServeArgs),

    /// Database operations
    #[command(subcommand)]
    Db(DbCommands),
}

#[derive(Args)]
struct ServeArgs {
    /// Port to listen on
    #[arg(short, long, default_value = "8080")]
    port: u16,

    /// Host to bind to
    #[arg(long, default_value = "127.0.0.1")]
    host: String,

    /// Enable hot reload
    #[arg(long)]
    hot_reload: bool,
}

#[derive(Subcommand)]
enum DbCommands {
    /// Run pending migrations
    Migrate,
    /// Reset database
    Reset {
        #[arg(long)]
        force: bool,
    },
}

fn main() {
    let cli = Cli::parse();

    if cli.verbose {
        println!("Verbose mode enabled");
    }

    match cli.command {
        Commands::Init { path, template } => {
            println!("Initializing project at {:?} with template {}", path, template);
        }
        Commands::Serve(args) => {
            println!("Starting server on {}:{}", args.host, args.port);
        }
        Commands::Db(cmd) => match cmd {
            DbCommands::Migrate => println!("Running migrations"),
            DbCommands::Reset { force } => {
                if force {
                    println!("Force resetting database");
                }
            }
        },
    }
}
```

### Argument Types

```rust
use clap::Parser;
use std::path::PathBuf;

#[derive(Parser)]
struct Args {
    // Positional argument (required)
    input: PathBuf,

    // Optional positional
    output: Option<PathBuf>,

    // Flag (presence = true)
    #[arg(short, long)]
    verbose: bool,

    // Option with value
    #[arg(short, long)]
    count: Option<u32>,

    // Required option
    #[arg(short, long)]
    name: String,

    // With default value
    #[arg(long, default_value = "info")]
    log_level: String,

    // Environment variable fallback
    #[arg(long, env = "DATABASE_URL")]
    database_url: String,

    // Multiple values
    #[arg(short, long)]
    tags: Vec<String>,

    // Value from set
    #[arg(long, value_parser = ["debug", "info", "warn", "error"])]
    level: String,

    // Counting flag (-v, -vv, -vvv)
    #[arg(short = 'v', long, action = clap::ArgAction::Count)]
    verbosity: u8,
}
```

### Custom Validation

```rust
use clap::Parser;
use std::path::PathBuf;

fn parse_port(s: &str) -> Result<u16, String> {
    let port: u16 = s.parse().map_err(|_| format!("Invalid port: {}", s))?;
    if port < 1024 {
        return Err("Port must be >= 1024 (non-privileged)".to_string());
    }
    Ok(port)
}

fn validate_path_exists(s: &str) -> Result<PathBuf, String> {
    let path = PathBuf::from(s);
    if !path.exists() {
        return Err(format!("Path does not exist: {}", s));
    }
    Ok(path)
}

#[derive(Parser)]
struct Args {
    #[arg(short, long, value_parser = parse_port)]
    port: u16,

    #[arg(value_parser = validate_path_exists)]
    config: PathBuf,
}
```

### Help and Documentation

```rust
use clap::Parser;

#[derive(Parser)]
#[command(
    name = "myapp",
    version,
    author,
    about = "A brief description",
    long_about = "A longer description that appears in --help.\n\n\
                  This can span multiple lines and provide detailed\n\
                  information about the application."
)]
#[command(propagate_version = true)]
#[command(arg_required_else_help = true)]
struct Cli {
    /// Short help shown in command list
    ///
    /// Longer help text that appears when using --help.
    /// This can include examples and detailed explanations.
    #[arg(short, long)]
    verbose: bool,
}
```

**Cargo.toml for version propagation:**

```toml
[package]
name = "myapp"
version = "0.1.0"
edition = "2024"

[dependencies]
clap = { version = "4", features = ["derive", "env"] }
```

## 2. Terminal UI with Ratatui

Ratatui is the standard framework for building terminal user interfaces. It uses an immediate-mode rendering approach with the crossterm backend.

### Basic Setup

```rust
use std::io;
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::{
    prelude::*,
    widgets::{Block, Borders, Paragraph},
};

fn main() -> io::Result<()> {
    // Setup terminal
    enable_raw_mode()?;
    io::stdout().execute(EnterAlternateScreen)?;
    let mut terminal = Terminal::new(CrosstermBackend::new(io::stdout()))?;

    // Run application
    let result = run(&mut terminal);

    // Restore terminal
    disable_raw_mode()?;
    io::stdout().execute(LeaveAlternateScreen)?;

    result
}

fn run(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>) -> io::Result<()> {
    let mut counter = 0;

    loop {
        // Draw UI
        terminal.draw(|frame| {
            let area = frame.area();
            let block = Block::default()
                .borders(Borders::ALL)
                .title("Counter (Space to increment, Q to quit)");
            let text = Paragraph::new(format!("Count: {}", counter))
                .block(block)
                .alignment(Alignment::Center);
            frame.render_widget(text, area);
        })?;

        // Handle events
        if let Event::Key(key) = event::read()? {
            if key.kind == KeyEventKind::Press {
                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => break,
                    KeyCode::Char(' ') => counter += 1,
                    KeyCode::Char('r') => counter = 0,
                    _ => {}
                }
            }
        }
    }

    Ok(())
}
```

### Application Structure with State

```rust
use std::io;
use crossterm::event::{self, Event, KeyCode, KeyEventKind};
use ratatui::prelude::*;

struct App {
    items: Vec<String>,
    selected: usize,
    should_quit: bool,
}

impl App {
    fn new() -> Self {
        Self {
            items: vec![
                "Item 1".to_string(),
                "Item 2".to_string(),
                "Item 3".to_string(),
            ],
            selected: 0,
            should_quit: false,
        }
    }

    fn next(&mut self) {
        if self.selected < self.items.len() - 1 {
            self.selected += 1;
        }
    }

    fn previous(&mut self) {
        if self.selected > 0 {
            self.selected -= 1;
        }
    }

    fn handle_event(&mut self) -> io::Result<()> {
        if let Event::Key(key) = event::read()? {
            if key.kind == KeyEventKind::Press {
                match key.code {
                    KeyCode::Char('q') => self.should_quit = true,
                    KeyCode::Down | KeyCode::Char('j') => self.next(),
                    KeyCode::Up | KeyCode::Char('k') => self.previous(),
                    _ => {}
                }
            }
        }
        Ok(())
    }
}
```

### Layout System

```rust
use ratatui::{
    prelude::*,
    widgets::{Block, Borders, Paragraph},
};

fn draw(frame: &mut Frame, app: &App) {
    // Vertical split: header, main content, footer
    let main_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),    // Header: fixed 3 lines
            Constraint::Min(0),       // Main: fill remaining
            Constraint::Length(1),    // Footer: 1 line
        ])
        .split(frame.area());

    // Horizontal split for main content
    let content_layout = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(30),  // Sidebar: 30%
            Constraint::Percentage(70),  // Content: 70%
        ])
        .split(main_layout[1]);

    // Render header
    let header = Paragraph::new("My Application")
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::BOTTOM));
    frame.render_widget(header, main_layout[0]);

    // Render sidebar
    let sidebar = Block::default()
        .title("Navigation")
        .borders(Borders::ALL);
    frame.render_widget(sidebar, content_layout[0]);

    // Render main content
    let content = Block::default()
        .title("Content")
        .borders(Borders::ALL);
    frame.render_widget(content, content_layout[1]);

    // Render footer
    let footer = Paragraph::new("Press 'q' to quit")
        .style(Style::default().fg(Color::DarkGray));
    frame.render_widget(footer, main_layout[2]);
}
```

### Core Widgets

```rust
use ratatui::{
    prelude::*,
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph, Table, Row, Cell},
};

fn render_widgets(frame: &mut Frame, area: Rect, app: &App) {
    // Paragraph with styling
    let paragraph = Paragraph::new(vec![
        Line::from(vec![
            Span::raw("Normal text, "),
            Span::styled("bold text", Style::default().add_modifier(Modifier::BOLD)),
            Span::raw(", and "),
            Span::styled("colored", Style::default().fg(Color::Cyan)),
        ]),
        Line::from("Second line"),
    ])
    .block(Block::default().title("Paragraph").borders(Borders::ALL))
    .wrap(ratatui::widgets::Wrap { trim: true });

    // List
    let items: Vec<ListItem> = app.items
        .iter()
        .enumerate()
        .map(|(i, item)| {
            let style = if i == app.selected {
                Style::default().bg(Color::Blue).fg(Color::White)
            } else {
                Style::default()
            };
            ListItem::new(item.clone()).style(style)
        })
        .collect();

    let list = List::new(items)
        .block(Block::default().title("List").borders(Borders::ALL))
        .highlight_style(Style::default().add_modifier(Modifier::BOLD));

    // Table
    let rows = vec![
        Row::new(vec![
            Cell::from("Row 1"),
            Cell::from("Data 1"),
            Cell::from("100"),
        ]),
        Row::new(vec![
            Cell::from("Row 2"),
            Cell::from("Data 2"),
            Cell::from("200"),
        ]),
    ];

    let table = Table::new(
        rows,
        [
            Constraint::Length(10),
            Constraint::Min(10),
            Constraint::Length(10),
        ],
    )
    .header(Row::new(vec!["Name", "Value", "Count"])
        .style(Style::default().add_modifier(Modifier::BOLD)))
    .block(Block::default().title("Table").borders(Borders::ALL));

    // Gauge (progress bar)
    let gauge = Gauge::default()
        .block(Block::default().title("Progress").borders(Borders::ALL))
        .gauge_style(Style::default().fg(Color::Green))
        .percent(75)
        .label("75%");
}
```

### Styling and Theming

```rust
use ratatui::prelude::*;

// Define a theme
struct Theme {
    background: Color,
    foreground: Color,
    highlight: Color,
    border: Color,
    error: Color,
}

impl Default for Theme {
    fn default() -> Self {
        Self {
            background: Color::Reset,
            foreground: Color::White,
            highlight: Color::Cyan,
            border: Color::Gray,
            error: Color::Red,
        }
    }
}

// Apply theme to styles
fn styled_block(theme: &Theme, title: &str) -> Block {
    Block::default()
        .title(title)
        .borders(Borders::ALL)
        .border_style(Style::default().fg(theme.border))
        .title_style(Style::default().fg(theme.highlight))
}

// Style modifiers
fn example_styles() {
    let bold = Style::default().add_modifier(Modifier::BOLD);
    let italic = Style::default().add_modifier(Modifier::ITALIC);
    let underlined = Style::default().add_modifier(Modifier::UNDERLINED);
    let combined = Style::default()
        .fg(Color::Yellow)
        .bg(Color::Blue)
        .add_modifier(Modifier::BOLD | Modifier::ITALIC);

    // RGB colors
    let custom_color = Style::default().fg(Color::Rgb(255, 128, 0));

    // 256 color palette
    let indexed_color = Style::default().fg(Color::Indexed(208));
}
```

### Event Handling with Timeout

```rust
use std::time::Duration;
use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};

fn handle_events(app: &mut App) -> io::Result<bool> {
    // Poll with timeout for async updates
    if event::poll(Duration::from_millis(100))? {
        match event::read()? {
            Event::Key(key) if key.kind == KeyEventKind::Press => {
                match (key.modifiers, key.code) {
                    (KeyModifiers::CONTROL, KeyCode::Char('c')) => return Ok(true),
                    (KeyModifiers::CONTROL, KeyCode::Char('q')) => return Ok(true),
                    (_, KeyCode::Up) => app.previous(),
                    (_, KeyCode::Down) => app.next(),
                    (_, KeyCode::Enter) => app.select_current(),
                    (_, KeyCode::Char(c)) => app.handle_char(c),
                    _ => {}
                }
            }
            Event::Mouse(mouse) => {
                // Handle mouse events if enabled
                app.handle_mouse(mouse);
            }
            Event::Resize(width, height) => {
                app.handle_resize(width, height);
            }
            _ => {}
        }
    }
    Ok(false)
}
```

## 3. Desktop Applications with Tauri 2.0

Tauri enables building desktop applications with web frontends and Rust backends. Version 2.0 introduces mobile support and a new ACL-based permission system.

### Architecture Overview

```
Frontend: React/Vue/Svelte/Solid/Leptos -> WebView
    |
    | IPC (JSON-RPC via invoke())
    v
Backend: Rust (Tauri Core)
    |
    | System APIs
    v
OS: Native file I/O, networking, notifications, etc.
```

### Tauri vs Electron

| Metric | Tauri 2.0 | Electron |
|--------|-----------|----------|
| Bundle Size | 2-10 MB | 80-150 MB |
| Memory Usage | 30-50 MB | 200-300 MB |
| Startup Time | 0.3-1.0s | 1-3s |
| Backend Language | Rust | Node.js |
| Rendering Engine | System WebView | Chromium |

### Project Setup

```bash
# Install create-tauri-app
cargo install create-tauri-app

# Create new project
cargo create-tauri-app my-app
cd my-app
```

**src-tauri/Cargo.toml:**

```toml
[package]
name = "my-app"
version = "0.1.0"
edition = "2024"

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = [] }
tauri-plugin-shell = "2"
tauri-plugin-fs = "2"
tauri-plugin-dialog = "2"
tauri-plugin-notification = "2"
tauri-plugin-http = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
```

### Capabilities (ACL System)

Tauri 2.0 uses a fine-grained permission system. Create capability files in `src-tauri/capabilities/`:

**src-tauri/capabilities/default.json:**

```json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Default permissions for the main window",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "core:window:allow-close",
    "core:window:allow-minimize",
    "core:window:allow-maximize",
    "shell:allow-open",
    "fs:allow-read-text-file",
    "fs:allow-write-text-file",
    "dialog:allow-open",
    "dialog:allow-save",
    "notification:default"
  ]
}
```

**Permission identifiers follow the pattern:** `plugin-name:permission-name`

Common permissions:
- `core:default` - Basic window operations
- `shell:allow-open` - Open URLs/files with default app
- `fs:allow-read-text-file` - Read text files
- `fs:allow-write-text-file` - Write text files
- `dialog:allow-open` - Show file open dialog
- `dialog:allow-save` - Show file save dialog
- `http:default` - HTTP client access

### Tauri Commands

```rust
// src-tauri/src/lib.rs
use serde::{Deserialize, Serialize};
use tauri::Manager;

#[derive(Debug, Serialize, Deserialize)]
struct FileInfo {
    name: String,
    size: u64,
    content: String,
}

// Simple synchronous command
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! Welcome to Tauri 2.0", name)
}

// Async command with Result
#[tauri::command]
async fn read_file(path: String) -> Result<FileInfo, String> {
    let content = tokio::fs::read_to_string(&path)
        .await
        .map_err(|e| e.to_string())?;

    let metadata = tokio::fs::metadata(&path)
        .await
        .map_err(|e| e.to_string())?;

    Ok(FileInfo {
        name: path.split('/').last().unwrap_or("unknown").to_string(),
        size: metadata.len(),
        content,
    })
}

// Command with app handle for emitting events
#[tauri::command]
async fn process_data(app: tauri::AppHandle, data: Vec<String>) -> Result<(), String> {
    for (i, item) in data.iter().enumerate() {
        // Process item...
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;

        // Emit progress event to frontend
        app.emit("progress", (i + 1, data.len()))
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}
```

### State Management

```rust
use std::sync::Mutex;
use tauri::Manager;

// Application state
struct AppState {
    counter: Mutex<i32>,
    config: Mutex<Config>,
}

#[derive(Default, Clone)]
struct Config {
    theme: String,
    language: String,
}

// Access state in commands
#[tauri::command]
fn increment(state: tauri::State<'_, AppState>) -> i32 {
    let mut counter = state.counter.lock().unwrap();
    *counter += 1;
    *counter
}

#[tauri::command]
fn get_config(state: tauri::State<'_, AppState>) -> Config {
    state.config.lock().unwrap().clone()
}

#[tauri::command]
fn set_theme(state: tauri::State<'_, AppState>, theme: String) {
    state.config.lock().unwrap().theme = theme;
}

// Entry point with mobile support
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .manage(AppState {
            counter: Mutex::new(0),
            config: Mutex::new(Config::default()),
        })
        .invoke_handler(tauri::generate_handler![
            greet,
            read_file,
            process_data,
            increment,
            get_config,
            set_theme,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### Frontend Communication

**JavaScript/TypeScript:**

```typescript
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';

// Call Rust commands
async function greetUser(name: string): Promise<string> {
  return await invoke('greet', { name });
}

// Call async command with complex return type
interface FileInfo {
  name: string;
  size: number;
  content: string;
}

async function loadFile(path: string): Promise<FileInfo> {
  return await invoke('read_file', { path });
}

// Listen for events from Rust
async function processWithProgress(data: string[]) {
  const unlisten = await listen('progress', (event) => {
    const [current, total] = event.payload as [number, number];
    console.log(`Progress: ${current}/${total}`);
  });

  try {
    await invoke('process_data', { data });
  } finally {
    unlisten();
  }
}
```

### Error Handling in Commands

```rust
use serde::Serialize;

// Custom error type
#[derive(Debug, Serialize)]
struct CommandError {
    code: String,
    message: String,
}

impl From<std::io::Error> for CommandError {
    fn from(err: std::io::Error) -> Self {
        CommandError {
            code: "IO_ERROR".to_string(),
            message: err.to_string(),
        }
    }
}

impl From<serde_json::Error> for CommandError {
    fn from(err: serde_json::Error) -> Self {
        CommandError {
            code: "JSON_ERROR".to_string(),
            message: err.to_string(),
        }
    }
}

#[tauri::command]
async fn save_config(path: String, config: Config) -> Result<(), CommandError> {
    let json = serde_json::to_string_pretty(&config)?;
    tokio::fs::write(&path, json).await?;
    Ok(())
}
```

## 4. Embedded Systems

Rust's `no_std` mode enables development for microcontrollers and other constrained environments without the standard library.

### no_std Development

```rust
#![no_std]  // Don't link the Rust standard library
#![no_main] // Don't use the standard main entry point

use core::panic::PanicInfo;

// Panic handler is required in no_std
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

// For debug builds, you might want more info
#[cfg(debug_assertions)]
#[panic_handler]
fn panic_debug(info: &PanicInfo) -> ! {
    // Log panic info via debug probe
    if let Some(location) = info.location() {
        // Use defmt or similar for logging
    }
    loop {}
}
```

**Cargo.toml for embedded:**

```toml
[package]
name = "firmware"
version = "0.1.0"
edition = "2024"

[dependencies]
cortex-m = "0.7"
cortex-m-rt = "0.7"
panic-halt = "0.2"  # Simple panic handler
# Or for debug output:
# panic-probe = { version = "0.3", features = ["print-defmt"] }
defmt = "0.3"
defmt-rtt = "0.4"

# HAL for your specific chip
stm32f4xx-hal = { version = "0.21", features = ["stm32f411"] }

[profile.release]
opt-level = "s"      # Optimize for size
lto = true
codegen-units = 1
debug = true         # Keep debug info for probe-rs
```

### Cortex-M (ARM Microcontrollers)

```rust
#![no_std]
#![no_main]

use cortex_m_rt::entry;
use panic_halt as _;
use stm32f4xx_hal::{pac, prelude::*};

#[entry]
fn main() -> ! {
    // Take ownership of peripherals
    let dp = pac::Peripherals::take().unwrap();
    let cp = cortex_m::Peripherals::take().unwrap();

    // Configure clocks
    let rcc = dp.RCC.constrain();
    let clocks = rcc.cfgr.sysclk(84.MHz()).freeze();

    // Configure GPIO
    let gpioa = dp.GPIOA.split();
    let mut led = gpioa.pa5.into_push_pull_output();

    // Configure delay
    let mut delay = cp.SYST.delay(&clocks);

    // Main loop - blink LED
    loop {
        led.set_high();
        delay.delay_ms(500u32);
        led.set_low();
        delay.delay_ms(500u32);
    }
}
```

### Embassy (Async Embedded)

Embassy provides an async runtime for embedded systems, enabling concurrent tasks without an OS.

```rust
#![no_std]
#![no_main]

use embassy_executor::Spawner;
use embassy_stm32::gpio::{Level, Output, Speed};
use embassy_time::{Duration, Timer};
use defmt::*;
use defmt_rtt as _;
use panic_probe as _;

#[embassy_executor::main]
async fn main(spawner: Spawner) {
    let p = embassy_stm32::init(Default::default());

    // Spawn concurrent tasks
    spawner.spawn(blink_led(p.PA5)).unwrap();
    spawner.spawn(read_sensor()).unwrap();
    spawner.spawn(handle_uart(p.USART1)).unwrap();

    info!("System initialized");
}

#[embassy_executor::task]
async fn blink_led(pin: embassy_stm32::peripherals::PA5) {
    let mut led = Output::new(pin, Level::Low, Speed::Low);

    loop {
        led.set_high();
        Timer::after(Duration::from_millis(500)).await;
        led.set_low();
        Timer::after(Duration::from_millis(500)).await;
    }
}

#[embassy_executor::task]
async fn read_sensor() {
    loop {
        // Simulate sensor reading
        Timer::after(Duration::from_secs(1)).await;
        info!("Sensor reading complete");
    }
}

#[embassy_executor::task]
async fn handle_uart(uart: embassy_stm32::peripherals::USART1) {
    // UART handling would go here
    loop {
        Timer::after(Duration::from_millis(100)).await;
    }
}
```

**Embassy Cargo.toml:**

```toml
[package]
name = "embassy-app"
version = "0.1.0"
edition = "2024"

[dependencies]
embassy-executor = { version = "0.7", features = ["arch-cortex-m", "executor-thread"] }
embassy-time = { version = "0.4", features = ["tick-hz-32_768"] }
embassy-stm32 = { version = "0.3", features = ["stm32f411ce", "time-driver-any"] }
defmt = "0.3"
defmt-rtt = "0.4"
panic-probe = { version = "0.3", features = ["print-defmt"] }
cortex-m = { version = "0.7", features = ["critical-section-single-core"] }
cortex-m-rt = "0.7"
```

### Common Embedded Patterns

**Interrupt handling:**

```rust
use cortex_m::interrupt;
use core::cell::RefCell;
use cortex_m::interrupt::Mutex;

// Shared state between main and interrupt
static COUNTER: Mutex<RefCell<u32>> = Mutex::new(RefCell::new(0));

#[interrupt]
fn TIM2() {
    interrupt::free(|cs| {
        let mut counter = COUNTER.borrow(cs).borrow_mut();
        *counter += 1;
    });
}

fn read_counter() -> u32 {
    interrupt::free(|cs| {
        *COUNTER.borrow(cs).borrow()
    })
}
```

**defmt logging:**

```rust
use defmt::{debug, error, info, trace, warn};

fn process_data(data: &[u8]) {
    trace!("Processing {} bytes", data.len());
    info!("Data: {:?}", data);

    if data.is_empty() {
        warn!("Empty data received");
        return;
    }

    // defmt formatting
    debug!("First byte: {:#x}", data[0]);
}
```

### Debugging with probe-rs

```bash
# Install probe-rs
cargo install probe-rs-tools

# Flash and run with RTT output
cargo run --release

# Or flash only
probe-rs run --chip STM32F411CE target/thumbv7em-none-eabihf/release/firmware

# Debug with GDB
probe-rs gdb --chip STM32F411CE target/thumbv7em-none-eabihf/release/firmware
```

**.cargo/config.toml:**

```toml
[target.thumbv7em-none-eabihf]
runner = "probe-rs run --chip STM32F411CE"
rustflags = ["-C", "link-arg=-Tlink.x"]

[build]
target = "thumbv7em-none-eabihf"
```

## 5. FFI & C Interop

Foreign Function Interface (FFI) allows Rust to call C code and be called from C.

### Calling C from Rust

```rust
use std::os::raw::{c_char, c_int, c_void};

// Declare external C functions
extern "C" {
    fn strlen(s: *const c_char) -> usize;
    fn printf(format: *const c_char, ...) -> c_int;
    fn malloc(size: usize) -> *mut c_void;
    fn free(ptr: *mut c_void);
}

// Link to a specific library
#[link(name = "mylib")]
extern "C" {
    fn mylib_init() -> c_int;
    fn mylib_process(data: *const u8, len: usize) -> c_int;
}

fn call_c_functions() {
    use std::ffi::CString;

    let s = CString::new("Hello").unwrap();

    unsafe {
        let len = strlen(s.as_ptr());
        println!("String length: {}", len);
    }
}
```

**Build script for linking (build.rs):**

```rust
fn main() {
    // Link to system library
    println!("cargo:rustc-link-lib=ssl");
    println!("cargo:rustc-link-lib=crypto");

    // Link to library in specific path
    println!("cargo:rustc-link-search=native=/usr/local/lib");
    println!("cargo:rustc-link-lib=static=mylib");
}
```

### Exposing Rust to C

```rust
use std::os::raw::c_char;
use std::ffi::{CStr, CString};

// Export function with C ABI
#[no_mangle]
pub extern "C" fn rust_add(a: i32, b: i32) -> i32 {
    a + b
}

// Export function that takes a string
#[no_mangle]
pub unsafe extern "C" fn rust_process_string(s: *const c_char) -> *mut c_char {
    if s.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = CStr::from_ptr(s);
    let rust_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let result = format!("Processed: {}", rust_str);

    match CString::new(result) {
        Ok(c_string) => c_string.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

// Corresponding free function
#[no_mangle]
pub unsafe extern "C" fn rust_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}
```

**Generated C header (using cbindgen):**

```c
// mylib.h
#ifndef MYLIB_H
#define MYLIB_H

#include <stdint.h>

int32_t rust_add(int32_t a, int32_t b);
char* rust_process_string(const char* s);
void rust_free_string(char* s);

#endif
```

### String Handling

```rust
use std::ffi::{CString, CStr};
use std::os::raw::c_char;

// Rust -> C: Use CString (owned, null-terminated)
fn pass_string_to_c() {
    let rust_string = "Hello, C!";

    // CString adds null terminator and owns the memory
    let c_string = CString::new(rust_string).expect("CString::new failed");

    unsafe {
        // as_ptr() returns *const c_char, valid as long as c_string lives
        some_c_function(c_string.as_ptr());
    }
    // c_string dropped here, memory freed
}

// C -> Rust: Use CStr (borrowed, null-terminated)
unsafe fn receive_string_from_c(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }

    // CStr borrows the C string, doesn't take ownership
    let c_str = CStr::from_ptr(ptr);

    // Convert to Rust string (validates UTF-8)
    c_str.to_str().ok().map(|s| s.to_string())
}

// When C transfers ownership to Rust
unsafe fn take_ownership_from_c(ptr: *mut c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }

    // Take ownership of the C string
    let c_string = CString::from_raw(ptr);
    c_string.into_string().ok()
}
```

### Memory Safety and Ownership

```rust
use std::os::raw::c_void;

// Opaque pointer pattern - hide Rust struct from C
pub struct MyStruct {
    data: Vec<u8>,
    name: String,
}

// Create and return opaque pointer
#[no_mangle]
pub extern "C" fn mystruct_new() -> *mut c_void {
    let s = Box::new(MyStruct {
        data: Vec::new(),
        name: String::new(),
    });
    Box::into_raw(s) as *mut c_void
}

// Use opaque pointer
#[no_mangle]
pub unsafe extern "C" fn mystruct_set_name(ptr: *mut c_void, name: *const c_char) -> bool {
    if ptr.is_null() || name.is_null() {
        return false;
    }

    let s = &mut *(ptr as *mut MyStruct);
    match CStr::from_ptr(name).to_str() {
        Ok(n) => {
            s.name = n.to_string();
            true
        }
        Err(_) => false,
    }
}

// Free opaque pointer - MUST be called by C code
#[no_mangle]
pub unsafe extern "C" fn mystruct_free(ptr: *mut c_void) {
    if !ptr.is_null() {
        drop(Box::from_raw(ptr as *mut MyStruct));
    }
}
```

### Error Handling Across FFI

```rust
use std::os::raw::c_int;

// Error codes for C
pub const SUCCESS: c_int = 0;
pub const ERROR_NULL_POINTER: c_int = -1;
pub const ERROR_INVALID_UTF8: c_int = -2;
pub const ERROR_INTERNAL: c_int = -3;

// Thread-local error message
thread_local! {
    static LAST_ERROR: std::cell::RefCell<Option<String>> = std::cell::RefCell::new(None);
}

fn set_last_error(msg: String) {
    LAST_ERROR.with(|e| {
        *e.borrow_mut() = Some(msg);
    });
}

#[no_mangle]
pub extern "C" fn get_last_error() -> *const c_char {
    LAST_ERROR.with(|e| {
        match &*e.borrow() {
            Some(msg) => msg.as_ptr() as *const c_char,
            None => std::ptr::null(),
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn do_operation(data: *const u8, len: usize) -> c_int {
    if data.is_null() {
        set_last_error("Null pointer provided".to_string());
        return ERROR_NULL_POINTER;
    }

    let slice = std::slice::from_raw_parts(data, len);

    match process_data(slice) {
        Ok(_) => SUCCESS,
        Err(e) => {
            set_last_error(e.to_string());
            ERROR_INTERNAL
        }
    }
}
```

## 6. WebAssembly

Rust compiles to WebAssembly for high-performance web applications.

### Setup

```bash
# Install WASM target
rustup target add wasm32-unknown-unknown

# Install wasm-pack (recommended)
cargo install wasm-pack

# Install wasm-opt for size optimization (optional)
# brew install binaryen  # macOS
# apt install binaryen   # Ubuntu
```

**Project structure:**

```
wasm-project/
├── Cargo.toml
├── src/
│   └── lib.rs
└── www/              # JavaScript consumer
    ├── index.html
    └── index.js
```

**Cargo.toml:**

```toml
[package]
name = "my-wasm"
version = "0.1.0"
edition = "2024"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"
web-sys = { version = "0.3", features = [
    "console",
    "Window",
    "Document",
    "Element",
    "HtmlElement",
    "Node",
] }
serde = { version = "1", features = ["derive"] }
serde-wasm-bindgen = "0.6"

[profile.release]
opt-level = "s"
lto = true
```

### wasm-bindgen Basics

```rust
use wasm_bindgen::prelude::*;

// Export function to JavaScript
#[wasm_bindgen]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

// Export function with string parameters
#[wasm_bindgen]
pub fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}

// Import JavaScript functions
#[wasm_bindgen]
extern "C" {
    // console.log
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);

    // console.warn
    #[wasm_bindgen(js_namespace = console, js_name = warn)]
    fn console_warn(s: &str);

    // window.alert
    fn alert(s: &str);

    // Custom JavaScript function
    #[wasm_bindgen(js_namespace = myLib)]
    fn processData(data: &[u8]) -> Vec<u8>;
}

// Use imported functions
#[wasm_bindgen]
pub fn demo() {
    log("Hello from Rust!");
    console_warn("This is a warning");
}
```

### Exporting Structs

```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct Counter {
    count: u32,
    step: u32,
}

#[wasm_bindgen]
impl Counter {
    // Constructor
    #[wasm_bindgen(constructor)]
    pub fn new() -> Counter {
        Counter { count: 0, step: 1 }
    }

    // Static method
    #[wasm_bindgen]
    pub fn with_step(step: u32) -> Counter {
        Counter { count: 0, step }
    }

    // Instance methods
    #[wasm_bindgen]
    pub fn increment(&mut self) {
        self.count += self.step;
    }

    #[wasm_bindgen]
    pub fn decrement(&mut self) {
        self.count = self.count.saturating_sub(self.step);
    }

    // Getter
    #[wasm_bindgen(getter)]
    pub fn count(&self) -> u32 {
        self.count
    }

    // Setter
    #[wasm_bindgen(setter)]
    pub fn set_step(&mut self, step: u32) {
        self.step = step;
    }
}
```

### JavaScript Integration

**js-sys (JavaScript types):**

```rust
use wasm_bindgen::prelude::*;
use js_sys::{Array, Object, Reflect, Function, Promise};

#[wasm_bindgen]
pub fn create_array() -> Array {
    let arr = Array::new();
    arr.push(&JsValue::from(1));
    arr.push(&JsValue::from(2));
    arr.push(&JsValue::from(3));
    arr
}

#[wasm_bindgen]
pub fn create_object() -> Object {
    let obj = Object::new();
    Reflect::set(&obj, &"name".into(), &"Rust".into()).unwrap();
    Reflect::set(&obj, &"version".into(), &JsValue::from(1)).unwrap();
    obj
}
```

**web-sys (Web APIs):**

```rust
use wasm_bindgen::prelude::*;
use web_sys::{console, window, Document, Element};

#[wasm_bindgen]
pub fn manipulate_dom() -> Result<(), JsValue> {
    let window = window().ok_or("no window")?;
    let document = window.document().ok_or("no document")?;

    // Query element
    let element = document
        .get_element_by_id("app")
        .ok_or("no element with id 'app'")?;

    // Create new element
    let div = document.create_element("div")?;
    div.set_inner_html("<p>Created from Rust!</p>");
    div.set_class_name("rust-generated");

    // Append to DOM
    element.append_child(&div)?;

    // Log to console
    console::log_1(&"DOM manipulation complete".into());

    Ok(())
}

#[wasm_bindgen]
pub fn set_timeout_demo() {
    let window = window().unwrap();

    // Create closure for callback
    let closure = Closure::wrap(Box::new(|| {
        console::log_1(&"Timeout fired!".into());
    }) as Box<dyn Fn()>);

    window
        .set_timeout_with_callback_and_timeout_and_arguments_0(
            closure.as_ref().unchecked_ref(),
            1000,
        )
        .unwrap();

    // Important: prevent closure from being dropped
    closure.forget();
}
```

### Building and Bundling

```bash
# Build for web (ES modules, direct browser usage)
wasm-pack build --target web --release

# Build for bundlers (webpack, vite, etc.)
wasm-pack build --target bundler --release

# Build for Node.js
wasm-pack build --target nodejs --release
```

**Output structure:**

```
pkg/
├── my_wasm.js         # JavaScript glue code
├── my_wasm_bg.wasm    # WebAssembly binary
├── my_wasm_bg.wasm.d.ts
├── my_wasm.d.ts       # TypeScript definitions
└── package.json
```

**HTML usage (--target web):**

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>WASM Demo</title>
</head>
<body>
    <div id="app"></div>
    <script type="module">
        import init, { Counter, greet, manipulate_dom } from './pkg/my_wasm.js';

        async function run() {
            await init();

            console.log(greet("World"));

            const counter = new Counter();
            counter.increment();
            console.log(`Count: ${counter.count}`);

            manipulate_dom();
        }
        run();
    </script>
</body>
</html>
```

### Performance Guidelines

**When WASM wins (8-10x faster than JS):**
- CPU-intensive computation (cryptography, compression)
- Image/video processing
- Physics simulations, games
- Large data structure manipulation
- SIMD-parallelizable workloads (10-15x with WASM SIMD)

**When WASM loses:**
- DOM manipulation (must cross JS boundary)
- Simple CRUD operations (overhead not worth it)
- Network I/O (JS async is more efficient)
- Small operations (initialization overhead dominates)

**Best practice:** Use WASM for compute-heavy inner loops, JS for DOM and I/O.

### Binary Size Optimization

**Cargo.toml profile:**

```toml
[profile.release]
opt-level = "z"       # Optimize for size (even more than "s")
lto = true            # Link-time optimization
codegen-units = 1     # Single codegen unit for better optimization
panic = "abort"       # No unwinding code
strip = true          # Strip symbols
```

**Post-build optimization:**

```bash
# Build with wasm-pack
wasm-pack build --release

# Further optimize with wasm-opt (from Binaryen)
wasm-opt -Oz -o pkg/optimized.wasm pkg/my_wasm_bg.wasm

# Check sizes
ls -la pkg/*.wasm

# Compress for delivery
gzip -9 -k pkg/optimized.wasm
brotli -9 pkg/optimized.wasm
```

**Size comparison example:**

| Stage | Size |
|-------|------|
| Debug build | ~2 MB |
| Release build | ~200 KB |
| wasm-opt -Oz | ~150 KB |
| gzip | ~50 KB |
| brotli | ~40 KB |

## 7. Macros

Rust macros enable metaprogramming - writing code that writes code.

### Declarative Macros

Declarative macros use pattern matching with `macro_rules!`:

```rust
// Simple macro
macro_rules! say_hello {
    () => {
        println!("Hello!");
    };
}

// Macro with parameters
macro_rules! print_value {
    ($val:expr) => {
        println!("{} = {:?}", stringify!($val), $val);
    };
}

// Macro with repetition
macro_rules! vec_of_strings {
    ($($x:expr),* $(,)?) => {
        vec![$($x.to_string()),*]
    };
}

// Multiple patterns
macro_rules! calculate {
    (add $a:expr, $b:expr) => { $a + $b };
    (mul $a:expr, $b:expr) => { $a * $b };
    (neg $a:expr) => { -$a };
}

fn main() {
    say_hello!();

    let x = 42;
    print_value!(x);
    print_value!(x * 2);

    let strings = vec_of_strings!["a", "b", "c"];

    let sum = calculate!(add 1, 2);
    let product = calculate!(mul 3, 4);
}
```

**Fragment types:**
- `$x:expr` - Expression
- `$x:ident` - Identifier
- `$x:ty` - Type
- `$x:path` - Path (e.g., `std::vec::Vec`)
- `$x:stmt` - Statement
- `$x:block` - Block
- `$x:pat` - Pattern
- `$x:literal` - Literal
- `$x:tt` - Token tree (anything)

**Practical example - HashMap literal:**

```rust
macro_rules! hashmap {
    ($($key:expr => $value:expr),* $(,)?) => {{
        let mut map = ::std::collections::HashMap::new();
        $(map.insert($key, $value);)*
        map
    }};
}

let scores = hashmap! {
    "Alice" => 100,
    "Bob" => 85,
    "Carol" => 92,
};
```

### Procedural Macros

Procedural macros operate on token streams and require a separate crate:

**Cargo.toml for proc-macro crate:**

```toml
[package]
name = "my-macros"
version = "0.1.0"
edition = "2024"

[lib]
proc-macro = true

[dependencies]
syn = { version = "2", features = ["full"] }
quote = "1"
proc-macro2 = "1"
```

**Derive macro:**

```rust
// my-macros/src/lib.rs
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, DeriveInput, Data, Fields};

#[proc_macro_derive(Builder)]
pub fn derive_builder(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let name = &input.ident;
    let builder_name = syn::Ident::new(
        &format!("{}Builder", name),
        name.span(),
    );

    // Extract fields from struct
    let fields = match &input.data {
        Data::Struct(data) => match &data.fields {
            Fields::Named(fields) => &fields.named,
            _ => panic!("Builder only supports named fields"),
        },
        _ => panic!("Builder only supports structs"),
    };

    let field_names: Vec<_> = fields.iter().map(|f| &f.ident).collect();
    let field_types: Vec<_> = fields.iter().map(|f| &f.ty).collect();

    let expanded = quote! {
        pub struct #builder_name {
            #(#field_names: Option<#field_types>,)*
        }

        impl #builder_name {
            pub fn new() -> Self {
                Self {
                    #(#field_names: None,)*
                }
            }

            #(
                pub fn #field_names(mut self, value: #field_types) -> Self {
                    self.#field_names = Some(value);
                    self
                }
            )*

            pub fn build(self) -> Result<#name, &'static str> {
                Ok(#name {
                    #(#field_names: self.#field_names.ok_or(concat!(
                        stringify!(#field_names), " is required"
                    ))?,)*
                })
            }
        }

        impl #name {
            pub fn builder() -> #builder_name {
                #builder_name::new()
            }
        }
    };

    TokenStream::from(expanded)
}
```

**Usage:**

```rust
use my_macros::Builder;

#[derive(Builder, Debug)]
struct User {
    name: String,
    email: String,
    age: u32,
}

fn main() {
    let user = User::builder()
        .name("Alice".to_string())
        .email("alice@example.com".to_string())
        .age(30)
        .build()
        .unwrap();

    println!("{:?}", user);
}
```

**Attribute macro:**

```rust
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, ItemFn};

#[proc_macro_attribute]
pub fn log_calls(_attr: TokenStream, item: TokenStream) -> TokenStream {
    let input = parse_macro_input!(item as ItemFn);
    let fn_name = &input.sig.ident;
    let fn_block = &input.block;
    let fn_sig = &input.sig;
    let fn_vis = &input.vis;

    let expanded = quote! {
        #fn_vis #fn_sig {
            println!("Entering: {}", stringify!(#fn_name));
            let result = (|| #fn_block)();
            println!("Exiting: {}", stringify!(#fn_name));
            result
        }
    };

    TokenStream::from(expanded)
}
```

**Function-like macro:**

```rust
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, LitStr};

#[proc_macro]
pub fn sql(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as LitStr);
    let query = input.value();

    // Validate SQL at compile time
    if !query.to_uppercase().starts_with("SELECT") {
        return syn::Error::new(input.span(), "Only SELECT queries allowed")
            .to_compile_error()
            .into();
    }

    let expanded = quote! {
        #query
    };

    TokenStream::from(expanded)
}
```

### Debugging Macros

```bash
# Expand macros to see generated code
cargo expand

# Expand specific module
cargo expand module_name

# In tests
cargo expand --test test_name
```

**Using cargo-expand:**

```bash
cargo install cargo-expand

# View expanded code
cargo expand
```

## 8. Domain Stack Reference

### CLI Stack

```toml
[dependencies]
# Argument parsing
clap = { version = "4", features = ["derive", "env"] }
# Async runtime
tokio = { version = "1", features = ["full"] }
# Logging/tracing
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
# Error handling
anyhow = "1"
thiserror = "1"
# Progress bars
indicatif = "0.17"
# Terminal colors
colored = "2"
# Config files
config = "0.14"
toml = "0.8"
serde = { version = "1", features = ["derive"] }
```

### TUI Stack

```toml
[dependencies]
# TUI framework
ratatui = "0.29"
# Terminal backend
crossterm = "0.28"
# Async runtime (optional, for background tasks)
tokio = { version = "1", features = ["rt-multi-thread", "sync", "time"] }
# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"
# Time handling
chrono = "0.4"
```

### Desktop Stack (Tauri)

```toml
[dependencies]
# Tauri core
tauri = { version = "2", features = [] }
# Plugins
tauri-plugin-shell = "2"
tauri-plugin-fs = "2"
tauri-plugin-dialog = "2"
tauri-plugin-notification = "2"
tauri-plugin-http = "2"
# Database
sqlx = { version = "0.8", features = ["runtime-tokio", "sqlite"] }
# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"
# Async
tokio = { version = "1", features = ["full"] }

[build-dependencies]
tauri-build = { version = "2", features = [] }
```

### Embedded Stack (Embassy)

```toml
[dependencies]
# Embassy async runtime
embassy-executor = { version = "0.7", features = ["arch-cortex-m", "executor-thread"] }
embassy-time = { version = "0.4", features = ["tick-hz-32_768"] }
# HAL (chip-specific)
embassy-stm32 = { version = "0.3", features = ["stm32f411ce", "time-driver-any"] }
# Logging
defmt = "0.3"
defmt-rtt = "0.4"
# Panic handler
panic-probe = { version = "0.3", features = ["print-defmt"] }
# Core
cortex-m = { version = "0.7", features = ["critical-section-single-core"] }
cortex-m-rt = "0.7"

[profile.release]
opt-level = "s"
lto = true
debug = true
```

### WebAssembly Stack

```toml
[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
# WASM bindings
wasm-bindgen = "0.2"
# JavaScript types
js-sys = "0.3"
# Web APIs
web-sys = { version = "0.3", features = ["console", "Window", "Document"] }
# Serialization
serde = { version = "1", features = ["derive"] }
serde-wasm-bindgen = "0.6"
# Utilities
console_error_panic_hook = "0.1"

[profile.release]
opt-level = "z"
lto = true
codegen-units = 1
panic = "abort"
strip = true
```

## Cross-References

- For Cargo.toml configuration and workspace setup, see `rust-project-setup.md`
- For async patterns used in Embassy and Tauri, see `rust-implementation-patterns.md`
- For unsafe code guidelines in FFI, see `rust-testing-quality.md`
- For error handling patterns with `anyhow` and `thiserror`, see `rust-implementation-patterns.md`
