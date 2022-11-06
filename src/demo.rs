use std::error::Error;
use rand::{Rng};

pub const LEIPAE_COUNT: usize = 10;

#[derive(Debug)]
pub struct Demo {
    leipae: [[f32; 4]; LEIPAE_COUNT],
}

impl Demo {
    pub fn new() -> Result<Self, Box<dyn Error>> {
        let mut rng = rand::thread_rng();
        
        let leipae = [
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 1.0],
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 2.0],
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 3.0],
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 4.0],
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 5.0],
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 1.0],
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 2.0],
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 3.0],
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 4.0],
            [rng.gen_range(-10.0..10.0), rng.gen_range(1.0..10.0), rng.gen_range(-10.0..10.0), 5.0],
        ];

        return Ok(Self {
            leipae,
        });
    }

    pub fn leipae(&self) -> [[f32; 4]; LEIPAE_COUNT] {
        self.leipae
    }

    pub unsafe fn update(&mut self, dt: f32) {
        for i in 0..LEIPAE_COUNT {
            self.leipae[i][1] -= dt * 0.25;
            if self.leipae[i][1] < -2.0 {
                self.leipae[i][1] = 10.0;
            }
        }
    }
}
