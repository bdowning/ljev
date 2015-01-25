#include <math.h>
#include <stdio.h>
#include <ev.h>

double count = 0;

void nil_cb(struct ev_loop *loop, ev_watcher *w, int revents)
{
}

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
    #define N 6
    ev_idle timers[N];
    ev_prepare p;

    for (int i = 0; i < N; ++i) {
        ev_idle_init(&timers[i], cb/*, 0.002, 0.002*/);
        ev_idle_start(loop, &timers[i]);
    }

    ev_prepare_init(&p, nil_cb);
    ev_prepare_start(loop, &p);

    ev_run(loop, 0);
    return 0;
}
