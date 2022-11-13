use std::ops::Sub;
use std::time::{Duration, SystemTime};

use rand::Rng;

pub const LEIPAE_COUNT: usize = 10;

#[derive(Debug)]
pub enum Scene {
    Init,
    Intro,
    Closeup,
}

#[derive(Debug)]
pub struct Demo {
    leipae: [[f32; 4]; LEIPAE_COUNT],

    scene: Scene,

    epoch: SystemTime,
    last_tick: SystemTime,
    time: Duration,
    end: Duration,

    camera: [f32; 3],
    target: [f32; 3],

    is_paused: bool,
    is_exit: bool,
}

impl Demo {
    pub fn new() -> Self {
        let mut rng = rand::thread_rng();

        let mut leipae = [[0.0, 0.0, 0.0, 0.0]; LEIPAE_COUNT];

        for i in 0..leipae.len() {
            leipae[i][0] = rng.gen_range(-10.0..10.0);
            leipae[i][1] = rng.gen_range(1.0..10.0);
            leipae[i][2] = rng.gen_range(-10.0..10.0);
            leipae[i][3] = rng.gen_range(1.0..5.0);
        }

        let epoch = SystemTime::now();

        Self {
            is_paused: false,
            is_exit: false,

            leipae,
            scene: Scene::Init,

            epoch,
            last_tick: epoch,
            time: Duration::default(),
            end: Duration::default(),

            camera: [0.0, 0.0, 0.0],
            target: [0.0, 0.0, 0.0],
        }
    }

    pub fn reset(&mut self) {
        self.epoch = SystemTime::now();
        self.last_tick = self.epoch;
        self.time = Duration::default();
    }

    pub fn pause(&mut self) {
        self.is_paused = true;
    }

    pub fn resume(&mut self) {
        self.is_paused = false;
        self.epoch = SystemTime::now().sub(self.time);
    }

    pub fn leipae(&self) -> [[f32; 4]; LEIPAE_COUNT] {
        self.leipae
    }

    pub fn should_exit(&self) -> bool {
        self.is_exit
    }

    pub fn is_paused(&self) -> bool {
        self.is_paused
    }

    pub fn time(&self) -> f32 {
        self.time.as_secs_f32()
    }

    pub fn camera(&self) -> [f32; 3] {
        self.camera
    }

    pub fn target(&self) -> [f32; 3] {
        self.target
    }

    pub fn update(&mut self) {
        self.time = self.epoch.elapsed().unwrap();

        let dt = self.last_tick.elapsed().unwrap().as_secs_f32();
        let t = self.time.as_secs_f32();

        // self.camera = [20.0 * f32::cos(t / 20.0), 2.0, 40.0 * f32::sin(t / 20.0)];
        // self.target = [0.0, 2.0 * f32::sin(t / 10.0), 0.0];

        for i in 0..LEIPAE_COUNT {
            self.leipae[i][1] -= dt * 0.25;
            if self.leipae[i][1] < -2.0 {
                self.leipae[i][1] = 10.0;
            }
        }

        if self.time >= self.end {
            self.next_scene();
        }

        self.last_tick = SystemTime::now();
    }

    fn next_scene(&mut self) {
        match self.scene {
            Scene::Init => {
                self.scene = Scene::Intro;

                self.epoch = SystemTime::now();
                self.last_tick = SystemTime::now();
                self.time = Duration::default();
                self.end = Duration::from_secs_f32(5.0);

                self.camera = [20.0, 2.0, 40.0];
                self.target = [0.0, 2.0, 0.0];
            }
            Scene::Intro => {
                self.scene = Scene::Closeup;

                self.epoch = SystemTime::now();
                self.last_tick = SystemTime::now();
                self.time = Duration::default();
                self.end = Duration::from_secs_f32(5.0);

                self.camera = [5.0, 2.0, 4.0];
                self.target = [0.0, 0.0, 0.0];
            }
            Scene::Closeup => {
                self.is_exit = true;
            }
        }
    }
}
