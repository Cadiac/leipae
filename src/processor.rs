use std::collections::HashSet;
use std::error::Error;
use std::ops::Sub;
use std::time::{Duration, SystemTime};

use glutin::event::{Event, StartCause, VirtualKeyCode, WindowEvent};
use glutin::event_loop::{ControlFlow, EventLoop};
use glutin::platform::run_return::EventLoopExtRunReturn;
use glutin::window::Window;
use glutin::{ContextWrapper, PossiblyCurrent};

use crate::renderer::Renderer;

pub struct EventProcessor {
    keys_held: HashSet<VirtualKeyCode>,
    is_paused: bool,
    elapsed: Duration,
    epoch: SystemTime,
    last_tick: SystemTime,
}

impl EventProcessor {
    pub fn new() -> Self {
        let epoch = SystemTime::now();
        Self {
            keys_held: HashSet::new(),
            is_paused: false,
            elapsed: Duration::default(),
            epoch,
            last_tick: epoch,
        }
    }

    pub fn run(
        &mut self,
        mut event_loop: EventLoop<()>,
        gl_window: ContextWrapper<PossiblyCurrent, Window>,
        mut renderer: Renderer,
    ) -> Result<(), Box<dyn Error>> {
        self.epoch = SystemTime::now();

        let exit_code = event_loop.run_return(move |event, _, control_flow| {
            *control_flow = ControlFlow::Poll;

            match event {
                Event::LoopDestroyed => return,
                Event::DeviceEvent { event, .. } => match event {
                    _ => (),
                },
                Event::WindowEvent { event, .. } => match event {
                    WindowEvent::KeyboardInput {
                        input,
                        device_id: _,
                        is_synthetic: _,
                    } => match input.virtual_keycode {
                        Some(VirtualKeyCode::Escape) => *control_flow = ControlFlow::Exit,
                        Some(VirtualKeyCode::R) => {
                            unsafe { renderer.reload().unwrap() };
                        }
                        Some(VirtualKeyCode::T) => {
                            self.epoch = SystemTime::now();
                        }
                        Some(VirtualKeyCode::Space) => {
                            self.is_paused = true;
                        }
                        Some(VirtualKeyCode::B) => {
                            self.is_paused = false;
                            self.epoch = SystemTime::now().sub(self.elapsed);
                        }
                        Some(key_code) => {
                            if input.state == glutin::event::ElementState::Pressed {
                                self.keys_held.insert(key_code);
                            } else {
                                self.keys_held.remove(&key_code);
                            }
                        }
                        _ => (),
                    },
                    WindowEvent::CloseRequested => *control_flow = ControlFlow::Exit,
                    WindowEvent::Resized(size) => {
                        if size.width != 0 && size.height != 0 {
                            gl_window.resize(size);
                            unsafe {
                                renderer.resize(size.width, size.height);
                                gl::Viewport(0, 0, size.width as i32, size.height as i32);
                            }
                        }
                    }
                    _ => (),
                },
                Event::NewEvents(StartCause::Poll) | Event::RedrawRequested(_) => {
                    if !self.is_paused {
                        self.elapsed = self.epoch.elapsed().unwrap();
                        let dt = self.last_tick.elapsed().unwrap();
                        self.last_tick = SystemTime::now();

                        unsafe {
                            renderer.update(self.elapsed, dt);
                        }
    
                        gl_window.swap_buffers().unwrap();
                    }
                }
                _ => (),
            }
        });

        if exit_code == 0 {
            Ok(())
        } else {
            Err(format!("Exited with code: {}", exit_code).into())
        }
    }
}
