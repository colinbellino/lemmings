class_name Enums

enum JOBS {
    NONE = 1 << 0,
    CLIMBER = 1 << 1,
    FLOATER = 1 << 2,
    BOMBER = 1 << 3,
    BLOCKER = 1 << 4, 
    BUILDER = 1 << 5,
    BASHER = 1 << 6,
    MINER = 1 << 7,
    DIGGER = 1 << 8,
}

enum TOOLS {
    NONE = 0,
    JOB_CLIMBER = 1,
    JOB_FLOATER = 2,
    JOB_BOMBER = 3,
    JOB_BLOCKER = 4,
    JOB_BUILDER = 5,
    JOB_BASHER = 6,
    JOB_MINER = 7,
    JOB_DIGGER = 8,
    PAINT_RECT = 9,
    PAINT_CIRCLE = 10
    ERASE_RECT = 11,
    SPAWN_UNIT = 12,
    BOMB_ALL = 13,
}

enum PIXELS {
    EMPTY = 1 << 0
    BLOCK = 1 << 1
    PAINT = 1 << 2
}
