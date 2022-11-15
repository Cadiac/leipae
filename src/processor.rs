use std::error::Error;

use glutin::event::{ElementState, Event, MouseButton, StartCause, VirtualKeyCode, WindowEvent};
use glutin::event_loop::{ControlFlow, EventLoop};
use glutin::platform::run_return::EventLoopExtRunReturn;
use glutin::window::Window;
use glutin::{ContextWrapper, PossiblyCurrent};

use crate::demo::Demo;
use crate::renderer::Renderer;

pub struct EventProcessor {
    demo: Demo,
}

impl EventProcessor {
    pub fn new() -> Self {
        Self {
            demo: Demo::new(),
        }
    }

    pub fn run(
        &mut self,
        mut event_loop: EventLoop<()>,
        gl_window: ContextWrapper<PossiblyCurrent, Window>,
        mut renderer: Renderer,
    ) -> Result<(), Box<dyn Error>> {
        let exit_code = event_loop.run_return(move |event, _, control_flow| {
            *control_flow = ControlFlow::Poll;

            match event {
                Event::LoopDestroyed => return,
                Event::WindowEvent { event, .. } => match event {
                    WindowEvent::MouseInput { button: MouseButton::Left, state: ElementState::Pressed, .. } => {
                        self.demo.skip_to_next();
                    },
                    WindowEvent::KeyboardInput { input, .. } => match input.virtual_keycode {
                        Some(VirtualKeyCode::Escape) => *control_flow = ControlFlow::Exit,
                        Some(VirtualKeyCode::R) => {
                            unsafe {
                                renderer.reload().unwrap();
                                renderer.draw(&self.demo);
                                gl_window.swap_buffers().unwrap();
                            };
                        }
                        Some(VirtualKeyCode::T) => {
                            self.demo.reset();
                        }
                        Some(VirtualKeyCode::Space) => {
                            self.demo.pause();
                        }
                        Some(VirtualKeyCode::B) => {
                            self.demo.resume();
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
                    if !self.demo.is_paused() {
                        self.demo.update();

                        unsafe {
                            renderer.draw(&self.demo);
                        }

                        gl_window.swap_buffers().unwrap();
                    }
                }
                _ => (),
            }

            if self.demo.should_exit() {
                *control_flow = ControlFlow::Exit
            }
        });

        if exit_code == 0 {
            Ok(())
        } else {
            Err(format!("Exited with code: {}", exit_code).into())
        }
    }
}

impl Default for EventProcessor {
    fn default() -> Self {
        Self::new()
    }
}
