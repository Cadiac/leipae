use std::ops::{Sub, SubAssign};
use std::time::{Duration, SystemTime};

use rand::Rng;

pub const LEIPAE_COUNT: usize = 20;
pub const SCENE_ORDER: &[Scene] = &[
    Scene::Init,
    Scene::MovingForward,   // 15sec
    Scene::ForwardToTop,    // 15sec
    Scene::TopToForward,    // 15sec
    Scene::Intro,           // 30sec
    Scene::BackwardsCircle, // 10sec
    Scene::MovingUp,        // 15sec
    Scene::Ending,
];

#[derive(Clone, Copy)]
pub enum Scene {
    Init,
    Intro,
    Closeup,
    MovingForward,
    TopToForward,
    ForwardToTop,
    MovingUp,
    BackwardsCircle,
    Ending,
}

struct Leipae {
    x: f32,
    y: f32,
    z: f32,
    v: f32,
    scale: f32,
}

impl Leipae {
    fn new() -> Self {
        let mut rng = rand::thread_rng();

        Self {
            x: rng.gen_range(-10.0..10.0),
            y: rng.gen_range(2.0..15.0),
            z: rng.gen_range(-10.0..10.0),
            scale: rng.gen_range(1.0..5.0),
            v: 0.0,
        }
    }

    fn update(&mut self, dt: f32) {
        let a = -0.25;

        self.y += self.v * dt + 0.5 * a * dt * dt;
        self.v += a * dt;

        if self.y < -2.5 {
            self.y = 15.0;
            self.v = 0.0;
        }
    }

    fn uniform4_f32(&self) -> [f32; 4] {
        [self.x, self.y, self.z, self.scale]
    }
}

pub struct Demo {
    leipaes: Vec<Leipae>,

    scene: Scene,
    scene_idx: usize,

    epoch: SystemTime,
    last_tick: SystemTime,
    start: SystemTime,
    end: Duration,
    day_time: Duration,
    time: Duration,

    update_camera: fn(&[f32; 3], f32) -> [f32; 3],
    update_target: fn(&[f32; 3], f32) -> [f32; 3],

    camera: [f32; 3],
    target: [f32; 3],

    is_paused: bool,
    is_exit: bool,
}

fn noop_movement(pos: &[f32; 3], _time: f32) -> [f32; 3] {
    *pos
}

impl Demo {
    pub fn new() -> Self {
        let mut leipaes = Vec::with_capacity(LEIPAE_COUNT);

        for _ in 0..LEIPAE_COUNT {
            leipaes.push(Leipae::new());
        }

        let epoch = SystemTime::now();

        Self {
            is_paused: false,
            is_exit: false,

            leipaes,

            scene: Scene::Init,
            scene_idx: 0,

            epoch,
            last_tick: epoch,
            start: epoch,
            end: Duration::default(),
            time: Duration::default(),
            day_time: Duration::default(),

            camera: [0.0, 0.0, 0.0],
            target: [0.0, 0.0, 0.0],

            update_camera: noop_movement,
            update_target: noop_movement,
        }
    }

    pub fn reset(&mut self) {
        self.start = SystemTime::now();
        self.last_tick = self.epoch;
        self.time = Duration::default();
    }

    pub fn pause(&mut self) {
        self.is_paused = true;
    }

    pub fn resume(&mut self) {
        self.is_paused = false;
        self.start = SystemTime::now().sub(self.time);
    }

    pub fn leipae(&self) -> [[f32; 4]; LEIPAE_COUNT] {
        self.leipaes
            .iter()
            .map(|leipae| leipae.uniform4_f32())
            .collect::<Vec<_>>()
            .try_into()
            .unwrap()
    }

    pub fn should_exit(&self) -> bool {
        self.is_exit
    }

    pub fn is_paused(&self) -> bool {
        self.is_paused
    }

    pub fn skip_next(&mut self) {
        self.day_time += self.end - self.time;
        self.epoch.sub_assign(self.end - self.time);
        self.next_scene()
    }

    pub fn day_time(&self) -> f32 {
        self.day_time.as_secs_f32()
    }

    pub fn camera(&self) -> [f32; 3] {
        self.camera
    }

    pub fn target(&self) -> [f32; 3] {
        self.target
    }

    pub fn update(&mut self) {
        self.time = self.start.elapsed().unwrap();
        self.day_time = self.epoch.elapsed().unwrap();

        if self.time >= self.end {
            self.next_scene();
        }

        let dt = self.last_tick.elapsed().unwrap().as_secs_f32();
        let t = self.time.as_secs_f32();

        self.camera = (self.update_camera)(&self.camera, t);
        self.target = (self.update_target)(&self.target, t);

        for leipae in self.leipaes.iter_mut() {
            leipae.update(dt);
        }

        self.last_tick = SystemTime::now();
    }

    fn set_scene_duration(&mut self, duration: f32) {
        self.last_tick = SystemTime::now();
        self.time = Duration::default();
        self.start = SystemTime::now();
        self.end = Duration::from_secs_f32(duration);
    }

    fn next_scene(&mut self) {
        self.scene_idx += 1;
        self.scene = SCENE_ORDER[self.scene_idx % SCENE_ORDER.len()];

        match self.scene {
            Scene::Init => {
                self.scene = Scene::Intro;
            }
            Scene::Intro => {
                self.set_scene_duration(30.0);

                self.update_camera = |_pos: &[f32; 3], t: f32| {
                    [-20.0 * f32::cos(t / 20.0), 2.0, 30.0 * f32::sin(t / 20.0)]
                };
                self.update_target = |_pos: &[f32; 3], t: f32| [0.0, 2.0 * f32::sin(t / 10.0), 0.0];
            }
            Scene::Closeup => {
                self.set_scene_duration(5.0);

                self.target = [0.0, 0.0, 0.0];

                self.update_camera = |_pos: &[f32; 3], t: f32| {
                    [5.0 * f32::cos(t / 40.0), 2.0, 4.0 * f32::sin(t / 40.0)]
                };
                self.update_target = noop_movement;
            }
            Scene::TopToForward => {
                self.set_scene_duration(15.0);

                self.update_camera = |_pos: &[f32; 3], t: f32| [0.0, 3.0 - t / 10.0, -t / 10.0];
                self.update_target = |_pos: &[f32; 3], t: f32| [0.0, 0.0, -1.0 - t];
            }
            Scene::ForwardToTop => {
                self.set_scene_duration(15.0);

                self.update_camera =
                    |_pos: &[f32; 3], t: f32| [0.0, 1.5 + t / 10.0, -2.0 + t / 10.0];
                self.update_target = |_pos: &[f32; 3], t: f32| [0.0, 0.0, -20.0 + t];
            }
            Scene::MovingForward => {
                self.set_scene_duration(15.0);

                self.target = [3.0, 0.8, -100.0];

                self.update_camera = |_pos: &[f32; 3], t: f32| [3.0, 1.1, t / 15.0 * -20.0];
                self.update_target = noop_movement;
            }
            Scene::MovingUp => {
                self.set_scene_duration(20.0);

                self.target = [3.0, 0.0, -50.0];

                self.update_camera = |_pos: &[f32; 3], t: f32| [3.0, 0.9 + t / 10.0, 0.0];
                self.update_target = noop_movement;
            }
            Scene::BackwardsCircle => {
                self.set_scene_duration(10.0);

                self.update_camera = |_pos: &[f32; 3], t: f32| {
                    [
                        10.0 + -10.0 * f32::sin(t / 20.0),
                        2.0,
                        -10.0 * f32::cos(t / 20.0),
                    ]
                };
                self.update_target = |_pos: &[f32; 3], t: f32| [-10.0 + t, 2.0, -100.0];
            }
            Scene::Ending => {
                self.is_exit = true;
            }
        }
    }
}
