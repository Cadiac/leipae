use gl::types::*;
use std::error::Error;
use std::mem;
use std::ptr;
use std::str;

use crate::program::ShaderProgram;
use crate::shader::Shader;

// #[rustfmt::skip]
static VERTICES: [GLfloat; 12] = [
   -1.0, -1.0, 0.0,
    1.0, -1.0, 0.0,
   -1.0,  1.0, 0.0,
    1.0,  1.0, 0.0,
];

static VS_PATH: &str = "./src/shaders/vertex.glsl";
static FS_PATH: &str = "./src/shaders/fragment.glsl";
const VERTEX_SHADER: &str = include_str!("shaders/vertex.glsl");
const FRAGMENT_SHADER: &str = include_str!("shaders/fragment.glsl");

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

    pub fn reload(&mut self) -> Result<(), Box<dyn Error>> {
        let vs = Shader::from_file(VS_PATH, gl::VERTEX_SHADER)?;
        let fs = Shader::from_file(FS_PATH, gl::FRAGMENT_SHADER)?;

        self.program = ShaderProgram::new(vs, fs);

        Ok(())
    }

    pub unsafe fn resize(&mut self, width: u32, height: u32) {
        self.width = width as f32;
        self.height = height as f32;

        self.program.activate();
        self.program.set_uniform2_f32("iResolution", self.width, self.height);
    }

    pub unsafe fn draw(&self, t: f32) {
        gl::ClearColor(0.0, 0.0, 0.0, 1.0);
        gl::Clear(gl::COLOR_BUFFER_BIT);

        self.program.activate();
        self.program.set_uniform_f32("iTime", t);

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
