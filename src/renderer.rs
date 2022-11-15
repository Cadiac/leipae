use std::error::Error;
use std::mem;
use std::ptr;
use std::str;

use gl::types::*;

use crate::demo::Demo;
use crate::program::ShaderProgram;
use crate::shader::Shader;

// #[rustfmt::skip]
static VERTICES: [GLfloat; 12] = [
    -1.0, -1.0, 0.0, 1.0, -1.0, 0.0, -1.0, 1.0, 0.0, 1.0, 1.0, 0.0,
];

const VERTEX_SHADER: &str = include_str!("shaders/vertex.glsl");
const FRAGMENT_SHADER: &str = include_str!("shaders/fragment.min.glsl");

#[derive(Debug)]
pub struct Renderer {
    width: f32,
    height: f32,

    program: ShaderProgram,

    vao: GLuint,
    vbo: GLuint,
}

impl Renderer {
    pub fn new(width: f32, height: f32) -> Result<Self, Box<dyn Error>> {
        let vs = Shader::new(VERTEX_SHADER, gl::VERTEX_SHADER)?;
        let fs = Shader::new(FRAGMENT_SHADER, gl::FRAGMENT_SHADER)?;

        let program = ShaderProgram::new(vs, fs);

        let mut vbo: GLuint = 0;
        let mut vao: GLuint = 0;

        unsafe {
            gl::GenVertexArrays(1, &mut vao);
            gl::GenBuffers(1, &mut vbo);

            // Bind Vertex Array Object first
            gl::BindVertexArray(vao);

            // Bind Vertex Buffer Object and copy the vertices to it
            gl::BindBuffer(gl::ARRAY_BUFFER, vbo);
            gl::BufferData(
                gl::ARRAY_BUFFER,
                (VERTICES.len() * mem::size_of::<GLfloat>()) as GLsizeiptr,
                mem::transmute(&VERTICES[0]),
                gl::STATIC_DRAW,
            );

            program.activate();
            program.set_uniform2_f32("iResolution", width, height);

            // Define vertex data layout, only position
            gl::VertexAttribPointer(
                0,
                3,
                gl::FLOAT as GLenum,
                gl::FALSE as GLboolean,
                3 * mem::size_of::<f32>() as GLsizei,
                ptr::null(),
            );
            gl::EnableVertexAttribArray(0);

            // Unbind the VBO and VAO
            gl::BindBuffer(gl::ARRAY_BUFFER, 0);
            gl::BindVertexArray(0);
        }

        return Ok(Self {
            width,
            height,
            vao,
            vbo,
            program,
        });
    }

    pub unsafe fn reload(&mut self) -> Result<(), Box<dyn Error>> {
        let vs = Shader::from_file("src/shaders/vertex.glsl", gl::VERTEX_SHADER)?;
        let fs = Shader::from_file("src/shaders/fragment.glsl", gl::FRAGMENT_SHADER)?;

        self.program = ShaderProgram::new(vs, fs);
        unsafe {
            self.program.activate();
            self.program
                .set_uniform2_f32("iResolution", self.width, self.height);
        }

        Ok(())
    }

    pub unsafe fn resize(&mut self, width: u32, height: u32) {
        self.width = width as f32;
        self.height = height as f32;

        self.program.activate();
        self.program
            .set_uniform2_f32("iResolution", self.width, self.height);
    }

    pub unsafe fn draw(&mut self, demo: &Demo) {
        gl::ClearColor(0.0, 0.0, 0.0, 1.0);
        gl::Clear(gl::COLOR_BUFFER_BIT);

        let camera = demo.camera();
        let target = demo.target();

        self.program.activate();
        self.program.set_uniform_f32("iTime", demo.day_time());
        self.program
            .set_uniform3_f32("iCamera", camera[0], camera[1], camera[2]);
        self.program
            .set_uniform3_f32("iTarget", target[0], target[1], target[2]);
        self.program.set_uniform4_f32v("iLeipae", demo.leipae());

        // Kavinsky - Nightcall, 91 BPM
        // let bps = 91.0 / 60.0;
        // self.program.set_uniform_f32(
        //     "iBeat",
        //     0.2 * f32::abs(f32::powi(
        //         f32::sin(demo.day_time() * bps * std::f32::consts::PI),
        //         8,
        //     )),
        // );

        gl::BindVertexArray(self.vao);
        gl::DrawArrays(gl::TRIANGLE_STRIP, 0, 4);
        gl::BindVertexArray(0);
    }
}

impl Drop for Renderer {
    fn drop(&mut self) {
        unsafe {
            gl::DeleteBuffers(1, &self.vbo);
            gl::DeleteVertexArrays(1, &self.vao);
        }
    }
}
