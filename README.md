# 🍞🍞 Leipae 🍞🍞

![Screenshot](https://github.com/cadiac/leipae/raw/master/leipae.jpg)

A small outrun and bread themed Rust + OpenGL intro for [Demohäsä 2022](https://tietoteekkarikilta.fi/#!/events/985) demo competition.

- [YouTube](https://www.youtube.com/watch?v=K6h6xMnrbMk)

## Running

Follow [Rust](https://www.rust-lang.org/en-US/install.html) installation instructions.

```
$ cargo run --release
```

## Generating minified shaders

To generate minified GLSL shaders use the [Shader Minifier](https://github.com/laurentlb/Shader_Minifier) tool:

```
$ shader_minifier.exe -o ./src/shaders/fragment.min.glsl --format text --preserve-externals ./src/shaders/fragment.glsl
```

## Creating release build

With minified up to date shaders in place run

```
$ cargo run --release
```

This will produce the release build executable binary within `target/release/` directory.

## License

This project is released under [MIT](https://github.com/Cadiac/leipae/blob/master/LICENSE) license.

Some GLSL shader functions derived from [iquilezles.org](https://iquilezles.org/articles/), as indicated on the `fragment.glsl` file.
