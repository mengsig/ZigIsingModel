const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

//const assert = @import("std").debug.assert;

const GRID_SIZE: u32 = 1500;
const TOTAL_SIZE: u32 = GRID_SIZE * GRID_SIZE;
const CELL_SIZE: i8 = 1;
const WINDOW_SIZE: i32 = CELL_SIZE * GRID_SIZE;
const BETA: f32 = 0.44;

// Creating a random number generator
var prng = std.rand.DefaultPrng.init(0);
const randomGenerator = prng.random();

// Simply inline function for indexing
inline fn IDX(i: usize, j: usize) usize {
    return ((i + GRID_SIZE) % GRID_SIZE) * GRID_SIZE + ((j + GRID_SIZE) % GRID_SIZE);
}

// Time until next event

fn update(i: usize, forest: *[TOTAL_SIZE]u2) !void {
    var sum: i32 = 0;
    if (i > 0) {
        sum += forest[i - 1];
    }
    if (i < TOTAL_SIZE - 1) {
        sum += forest[i + 1];
    }
    if (i / GRID_SIZE > 0) {
        sum += forest[i - GRID_SIZE];
    }
    if (i / GRID_SIZE < GRID_SIZE - 1) {
        sum += forest[i + GRID_SIZE];
    }
    const thesum: i32 = switch (sum) {
        0 => -4,
        1 => -2,
        2 => 0,
        3 => 2,
        4 => 4,
        else => unreachable,
    };
    switch (forest[i]) {
        0 => {
            const newsum: f32 = @floatFromInt(-thesum);
            if (newsum <= 0) {
                forest[i] = 1;
            } else {
                const r1 = randomGenerator.float(f32);
                if (r1 < @exp(-2 * newsum * BETA)) {
                    forest[i] = 1;
                }
            }
        },
        1 => {
            const newsum: f32 = @floatFromInt(thesum);
            if (newsum <= 0) {
                forest[i] = 0;
            } else {
                const r1 = randomGenerator.float(f32);
                if (r1 < @exp(-2 * newsum * BETA)) {
                    //if (r1 < std.math.pow(f32, 2.718, -2 * newsum * BETA)) {
                    forest[i] = 0;
                }
            }
        },
        else => unreachable,
    }
}

fn systemUpdate(forest: *[TOTAL_SIZE]u2) void {
    for (0..TOTAL_SIZE) |i| {
        //const ouri: u32 = @intFromFloat(randomGenerator.float(f32) * TOTAL_SIZE);
        try update(i, forest);
    }
}

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const screen = c.SDL_CreateWindow("Ising Model", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, WINDOW_SIZE, WINDOW_SIZE, c.SDL_WINDOW_OPENGL) orelse
        {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    // Creating our forest & texture-buffer for display
    var textureBuffer: [TOTAL_SIZE]u32 = undefined;
    var forest: [TOTAL_SIZE]u2 = undefined;

    for (0..TOTAL_SIZE) |i| {
        forest[i] = @intFromBool(randomGenerator.boolean());
        if (forest[i] == 0) {
            textureBuffer[i] = 0x000000;
        } else {
            textureBuffer[i] = 0x00FF00;
        }
    }

    // Defining our print
    const stdout = std.io.getStdOut().writer();
    // Defining our texture
    const theTexture: ?*c.SDL_Texture = c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_ARGB8888, c.SDL_TEXTUREACCESS_STREAMING, GRID_SIZE, GRID_SIZE);

    var quit = false;
    var counter: u64 = 0;
    while (!quit) {
        //        if (counter > 100) {
        //            break;
        //        }
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }
        //const start1 = try std.time.Instant.now();
        render(&forest, &textureBuffer, theTexture);
        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderCopy(renderer, theTexture, null, null);
        _ = c.SDL_RenderPresent(renderer);
        //const end1 = try std.time.Instant.now();
        //const elapsed1: f64 = @floatFromInt(end1.since(start1));
        //try stdout.print("Render Time = {}ms \n", .{elapsed1 / std.time.ns_per_ms});
        const start2 = try std.time.Instant.now();
        systemUpdate(&forest);
        const end2 = try std.time.Instant.now();
        const elapsed2: f64 = @floatFromInt(end2.since(start2));
        const fps: i32 = @intFromFloat(1000 / (elapsed2 / std.time.ns_per_ms));
        try stdout.print("Framerate = {} \n", .{fps});
        counter += 1;
        try stdout.print("Time {} \n", .{counter});
    }
}

// Defining our render function
fn render(forest: *[TOTAL_SIZE]u2, textureBuffer: *[TOTAL_SIZE]u32, theTexture: ?*c.SDL_Texture) void {
    for (0..GRID_SIZE) |i| {
        for (0..GRID_SIZE) |j| {
            const index: usize = IDX(i, j);
            const state: u2 = forest[index];
            textureBuffer[index] = switch (state) {
                0 => 0x000000,
                1 => 0x00FF00,
                2 => 0xFF0000,
                else => unreachable,
            };
        }
    }
    _ = c.SDL_UpdateTexture(theTexture, null, textureBuffer, GRID_SIZE * @sizeOf(u32));
}
