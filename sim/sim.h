#ifndef SIM_H
#define SIM_H 1

#include <functional>

void sim_tick_until(std::function<bool()> until);

#endif // SIM_H
