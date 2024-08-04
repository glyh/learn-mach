// REF: https://github.com/hexops/mach/tree/0.4/examples/core/triangle
const mach = @import("mach");

// The global list of Mach modules registered for use in our application.
pub const modules = .{
    mach.Core,
    @import("app.zig"),
};

pub fn main() !void {
    // Initialize mach.Core
    try mach.core.initModule();

    // Main loop
    while (try mach.core.tick()) {}
}
