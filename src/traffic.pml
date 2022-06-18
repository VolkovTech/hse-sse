// FM Project, Andrey Volkov, Construction 12

// Lanes:
// 0-2: E
// 3-5: S
// 6-8: W
// 9-11: N
// 12: P (pedestrian crossing)
#define LANES_NUM 6
#define LAST_CAR_LANE 4

int state = 0;
int rules[LANES_NUM] =
{
    31, // 0: 011111
    38, // 1: 100110						
    36, // 2: 100100
    57, // 3: 111001
    49, // 4: 110001
    38  // 5: 100110 (crosswalk)
}

// Array that defines the number of lanes
int lanes_nums[LANES_NUM] = { 0, 1, 2, 3, 4, 5 }

mtype:light = { RED, GREEN }
mtype:light lights_color[LANES_NUM] =
{
    RED, RED, RED, RED, RED, RED, RED,
    RED, RED, RED, RED, RED, RED
}

mtype:actor = { CAR, PED }
// Channels for generating traffic actors
// Lanes 0-11 for cars,
// Lane 12 for pedestrians
chan lanes[LANES_NUM] = [1] of { mtype:actor }

// Control synchronization channels
chan control_send[LANES_NUM] = [0] of { int }
chan control_return[LANES_NUM] = [0] of { int }

proctype car_spawner (int lane) {
    assert(lane <= LAST_CAR_LANE);
    do
    :: lanes[lane]!CAR;
    od;
}

proctype pedestrian_spawner (int lane) {
    assert(lane > LAST_CAR_LANE && lane <= LANES_NUM);
    do
    :: lanes[lane]!PED;
    od;
}

proctype traffic_light (int lane) {
    int control_token;
    mtype:actor traffic_actor;
    do
    /// Wait until can turn on
    ::  lanes[lane]?[traffic_actor];
        do
        ::  control_send[lane]?control_token;
            assert(control_token == lane);
            //printf("Lane %d checks state: %d against condition %d\n", lane, state, rules[lane]);
            if
            ::  ((state & rules[lane]) == 0) ->
                //printf("Lane %d will change state to %d\n", lane, state | 1 << lane);
                state = state ^ 1 << lane;
                lights_color[lane] = GREEN;
                printf("Lane %d is good to go\n", lane);
            ::  else -> skip;
            fi;
            control_return[lane]!lane;
            if
            ::  lights_color[lane] == GREEN -> break;
            ::  else ->
                printf("Lane %d: could not turn GREEN\n", lane);
                skip;
            fi;
        od;

        /// Light is green, let cars pass
        lanes[lane]?traffic_actor;
        printf("Lane %d: passes a car/ped\n", lane);

        // lanes[lane]?num_cars;
        // do
        // ::  num_cars > 0 ->
        //     num_cars--;
        //     printf("Lane %d: passes a car/ped\n", lane);
        // ::  else -> break;
        // od;

        // do
        // ::  lanes[lane]?[traffic_actor] ->
        //     lanes[lane]?traffic_actor;
        //     printf("Lane %d: passes a car/ped\n", lane);
        // ::  else -> break;
        // od;

        /// Turn off
        control_send[lane]?control_token;
        assert(control_token == lane);
        lights_color[lane] = RED;
        //printf("Lane %d will change state to %d\n", lane, state & !(1 << lane));
        state = state ^ 1 << lane;
        printf("Lane %d: stopped\n", lane);
        control_return[lane]!lane;
    od;
}

proctype intersection_controller () {
    int next_lane_idx = 0;
    int next_lane = 0;
    int control_token = 0;

    do
    ::  next_lane = lanes_nums[next_lane_idx];
        control_send[next_lane]!next_lane;
        control_return[next_lane]?control_token;
        assert(control_token == next_lane)
        next_lane_idx = (next_lane_idx + 1) % LANES_NUM;
    od;
}

init {
    run intersection_controller();
    printf("Controller spawned\n");

    int new_lane_idx = 0;
    int new_lane = 0;
    do
    ::  new_lane_idx < LANES_NUM ->
        new_lane = lanes_nums[new_lane_idx];
        if
        ::  new_lane <= LAST_CAR_LANE ->
            run car_spawner(new_lane);
            //printf("Lane %d: started car spawner\n", new_lane);
        ::  else ->
            run pedestrian_spawner(new_lane);
            //printf("Lane %d: started pedestrian spawner\n", new_lane);
        fi;
        run traffic_light(lanes_nums[new_lane_idx]);
        //printf("Lane %d: started traffic light\n", new_lane);
        new_lane_idx++;
    ::  else ->
        break;
    od;
    printf("All processes started\n");
}

// Lanes: { 1, 5, 7, 10, 11, 12 }
mtype:actor dummy_actor;
#define sense(n) (lanes[n]?[dummy_actor])
#define allowed(n) (lights_color[n] == GREEN)

#define fair(n) ([]<> !(sense(n) && allowed(n)))
#define unfair(n) (<>[] (sense(n) && allowed(n)))
ltl fairness { fair(1) && fair(5) && fair(7) && fair(10) && fair(11) && fair(12) };

ltl safety {[]!(allowed(1) && (allowed(10) || allowed(11)) ||
                allowed(5) && (allowed(7) || allowed(10)) ||
                allowed(7) && allowed(10) ||
                allowed(12) && (allowed(1) || allowed(7) || allowed(11))) };

#define liv(n) ([] ((sense(n) && !allowed(n)) -> <> allowed(n)))
ltl liveness { liv(1) && liv(5) && liv(7) && liv(10) && liv(11) && liv(12) };

// ltl flive { (fair(1) && fair(5) && fair(7) && fair(10) && fair(11) && fair(12)) ->
//             (liv(1) && liv(5) && liv(7) && liv(10) && liv(11) && liv(12)) };

// ltl flive1 { (fair(1)) -> (liv(1)) };