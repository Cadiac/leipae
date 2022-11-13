use core::mem::transmute;
use std::ffi::CString;
use std::ptr;
use std::str;

use gl::types::*;

use crate::shader::Shader;
use crate::demo::LEIPAE_COUNT;

#[derive(Debug)]
pub struct ShaderProgram(GLuint);

impl ShaderProgram {
    pub fn new(vs: Shader, fs: Shader) -> Self {
        let program = unsafe { gl::CreateProgram() };

        unsafe {
            gl::AttachShader(program, vs.id());
            gl::AttachShader(program, fs.id());
            gl::LinkProgram(program);

            // Check if the linking is successful
            let mut success = gl::FALSE as GLint;
            gl::GetProgramiv(program, gl::LINK_STATUS, &mut success);

            if success != gl::TRUE as GLint {
                let mut log_buffer = Vec::with_capacity(512);
                gl::GetProgramInfoLog(
                    program,
                    512,
                    ptr::null_mut(),
                    log_buffer.as_mut_ptr() as *mut GLchar,
                );

                panic!(
                    "{}",
                    str::from_utf8(&log_buffer)
                        .ok()
                        .expect("ShaderInfoLog not valid utf8")
                );
            }
        }

        Self(program)
    }

    pub fn id(&self) -> GLuint {
        self.0
    }

    pub unsafe fn activate(&self) {
        gl::UseProgram(self.id());
    }

    pub unsafe fn set_uniform_f32(&self, name: &str, value: f32) {
        let name_c_str = CString::new(name.as_bytes()).unwrap();
        gl::Uniform1f(
            gl::GetUniformLocation(self.id(), name_c_str.as_ptr()),
            value,
        );
    }

    pub unsafe fn set_uniform2_f32(&self, name: &str, a: f32, b: f32) {
        let name_c_str = CString::new(name.as_bytes()).unwrap();
        gl::Uniform2f(gl::GetUniformLocation(self.id(), name_c_str.as_ptr()), a, b);
    }

    pub unsafe fn set_uniform3_f32(&self, name: &str, a: f32, b: f32, c: f32) {
        let name_c_str = CString::new(name.as_bytes()).unwrap();
        gl::Uniform3f(gl::GetUniformLocation(self.id(), name_c_str.as_ptr()), a, b, c);
    }

    pub unsafe fn set_uniform4_f32v(&self, name: &str, v: [[f32; 4]; LEIPAE_COUNT]) {
        let name_c_str = CString::new(name.as_bytes()).unwrap();
        gl::Uniform4fv(
            gl::GetUniformLocation(self.id(), name_c_str.as_ptr()),
            LEIPAE_COUNT as i32,
            transmute::<_, *const GLfloat>(v.as_ptr()),
        );
    }
}

impl Drop for ShaderProgram {
    fn drop(&mut self) {
        unsafe { gl::DeleteProgram(self.0) }
    }
}
