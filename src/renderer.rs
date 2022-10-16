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

#[derive(Debug)]
pub struct Renderer {
    program: ShaderProgram,
    vao: GLuint,
    vbo: GLuint,
    vs_path: &'static str,
    fs_path: &'static str,
}

impl Renderer {
    pub fn new(
        vs_path: &'static str,
        fs_path: &'static str,
    ) -> Result<Self, Box<dyn Error>> {
        let vs = Shader::from_file(vs_path, gl::VERTEX_SHADER)?;
        let fs = Shader::from_file(fs_path, gl::FRAGMENT_SHADER)?;

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
            vao,
            vbo,
            program,
            vs_path,
            fs_path,
        });
    }

    pub fn reload(&mut self) -> Result<(), Box<dyn Error>> {
        let vs = Shader::from_file(self.vs_path, gl::VERTEX_SHADER)?;
        let fs = Shader::from_file(self.fs_path, gl::FRAGMENT_SHADER)?;

        self.program = ShaderProgram::new(vs, fs);

        Ok(())
    }

    pub fn draw(&self, t: f32) {
        unsafe {
            gl::ClearColor(0.0, 0.0, 0.0, 1.0);
            gl::Clear(gl::COLOR_BUFFER_BIT);

            self.program.activate();
            self.program.set_uniform_f32("iTime", t);
            self.program.set_uniform2_f32("iResolution", 1600.0, 900.0);

            gl::BindVertexArray(self.vao);
            gl::DrawArrays(gl::TRIANGLE_STRIP, 0, 4);
            gl::BindVertexArray(0);
        }
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
