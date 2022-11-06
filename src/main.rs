use std::error::Error;

use processor::EventProcessor;
use renderer::Renderer;

pub mod processor;
pub mod program;
pub mod renderer;
pub mod shader;
pub mod demo;

const WIDTH: f32 = 1920.0;
const HEIGHT: f32 = 1080.0;

fn main() -> Result<(), Box<dyn Error>> {
    let event_loop = glutin::event_loop::EventLoop::new();
    let window = glutin::window::WindowBuilder::new()
        .with_title("demohäsä")
        .with_inner_size(glutin::dpi::LogicalSize::new(WIDTH, HEIGHT));

    let gl_window = glutin::ContextBuilder::new()
        .with_gl(glutin::GlRequest::Specific(glutin::Api::OpenGl, (3, 3)))
        .with_gl_profile(glutin::GlProfile::Core)
        .build_windowed(window, &event_loop)
        .expect("failed to build gl_window");

    let gl_window = unsafe { gl_window.make_current() }.expect("failed to make context current");

    gl::load_with(|symbol| gl_window.get_proc_address(symbol));

    let renderer = Renderer::new(WIDTH, HEIGHT)?;

    let mut processor = EventProcessor::new();

    processor.run(event_loop, gl_window, renderer)
}
