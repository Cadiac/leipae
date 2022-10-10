use gl::types::*;
use std::ffi::CString;
use std::ptr;
use std::str;
use std::fs;
use std::error::Error;
use std::fmt;

#[derive(Debug)]
pub struct Shader(GLuint);

impl Shader {
    pub fn new(shader_src: &str, shader_type: GLenum) -> Result<Self, ShaderError> {
        unsafe {
            let shader = gl::CreateShader(shader_type);
            let c_str = CString::new(shader_src.as_bytes()).unwrap();
            gl::ShaderSource(shader, 1, &c_str.as_ptr(), ptr::null());
            gl::CompileShader(shader);

            // Check if the compilation is successful
            let mut success = gl::FALSE as GLint;
            gl::GetShaderiv(shader, gl::COMPILE_STATUS, &mut success);

            if success != GLint::from(gl::TRUE) {
                Err(ShaderError(read_shader_error(shader)))
            } else {
                Ok(Self(shader))
            }

        }
    }

    pub fn from_file(file_path: &str, shader_type: GLenum) -> Result<Self, ShaderError> {
        let shader_src = match fs::read_to_string(file_path) {
            Ok(src) => src,
            Err(err) => return Err(ShaderError(format!("failed to read shader source file: {}", err)))
        };

        Shader::new(&shader_src, shader_type)
    }

    pub fn id(&self) -> GLuint {
        self.0
    }
}

impl Drop for Shader {
    fn drop(&mut self) {
        unsafe { gl::DeleteShader(self.0) }
    }
}

#[derive(Debug)]
pub struct ShaderError(pub String);

impl Error for ShaderError {}

impl fmt::Display for ShaderError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "failed at shader: {}", self.0)
    }
}

fn read_shader_error(shader: GLuint) -> String {
    let mut info_log_length: GLint = 0;
    unsafe {
        gl::GetShaderiv(shader, gl::INFO_LOG_LENGTH, &mut info_log_length);
    }

    let mut read_length: GLint = 0;
    let mut log_buffer = Vec::with_capacity(info_log_length as usize);
    unsafe {
        gl::GetShaderInfoLog(
            shader,
            info_log_length,
            &mut read_length,
            log_buffer.as_mut_ptr() as *mut GLchar
        );

        log_buffer.set_len(read_length as usize);
    }

    String::from_utf8_lossy(&log_buffer).to_string()
}
