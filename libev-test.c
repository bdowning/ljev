#include <math.h>
#include <stdio.h>
#include <ev.h>

double count = 0;

void cb(struct ev_loop *loop, ev_watcher *w, int revents)
{
    double div_cnt = count / 1000000;
    if (floor(div_cnt) == div_cnt)
        printf("%.0f\n", count);
    if (count == 20000000)
        ev_break(loop, EVBREAK_ALL);
    ++count;
}

int main()
{
    struct ev_loop *loop = ev_default_loop(0);
    #define N 6000
    ev_timer timers[N];

    for (int i = 0; i < N; ++i) {
        ev_timer_init(&timers[i], cb, 0.002, 0.002);
        ev_timer_start(loop, &timers[i]);
    }

    ev_run(loop, 0);
    return 0;
}
