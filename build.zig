const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const root_src_path = b.pathFromRoot("src");
    const root_src = try std.fs.openDirAbsolute(root_src_path, .{ .iterate = true });

    var iter = try root_src.walk(alloc);
    defer iter.deinit();

    while (try iter.next()) |entry| {
        if (entry.kind != .directory) continue;

        const demo_name = entry.basename;
        const demo_root_source = try std.fmt.allocPrint(alloc, "src/{s}/main.zig", .{demo_name});
        defer alloc.free(demo_root_source);

        const exe = b.addExecutable(.{
            .name = demo_name,
            .root_source_file = b.path(demo_root_source),
            .target = target,
            .optimize = optimize,
        });

        // Add dependencies
        const mach_dep = b.dependency("mach", .{
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("mach", mach_dep.module("mach"));
        @import("mach").link(mach_dep.builder, exe);

        const mach_freetype_dep = b.dependency("mach_freetype", .{
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("freetype", mach_freetype_dep.module("mach-freetype"));

        // This declares intent for the executable to be installed into the
        // standard location when the user invokes the "install" step (the default
        // step when running `zig build`).
        b.installArtifact(exe);

        // This *creates* a Run step in the build graph, to be executed when another
        // step is evaluated that depends on it. The next line below will establish
        // such a dependency.
        const run_cmd = b.addRunArtifact(exe);

        // By making the run step depend on the install step, it will be run from the
        // installation directory rather than directly from within the cache directory.
        // This is not necessary, however, if the application depends on other installed
        // files, this ensures they will be present and in the expected location.
        run_cmd.step.dependOn(b.getInstallStep());

        // This allows the user to pass arguments to the application in the build
        // command itself, like this: `zig build run -- arg1 arg2 etc`
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        // This creates a build step. It will be visible in the `zig build --help` menu,
        // and can be selected like this: `zig build run`
        // This will evaluate the `run` step rather than the default, which is "install".
        const run_step_name = try std.fmt.allocPrint(alloc, "run-{s}", .{demo_name});
        defer alloc.free(run_step_name);
        const run_step_desc = try std.fmt.allocPrint(alloc, "Run demo `{s}`", .{demo_name});
        defer alloc.free(run_step_desc);

        const run_step = b.step(run_step_name, run_step_desc);
        run_step.dependOn(&run_cmd.step);
    }
}
