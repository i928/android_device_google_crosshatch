/*
 * Copyright (C) 2018 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "BatteryRechargingControl.h"

namespace device {
namespace google {
namespace crosshatch {
namespace health {

using aidl::android::hardware::health::BatteryStatus;
using aidl::android::hardware::health::HealthInfo;

const std::string kChargerStatus = "/sys/class/power_supply/battery/status";

static const std::string kStatusIsFull = "Full";
static const std::string kStatusIsCharging = "Charging";
static constexpr int kTransitionTime = 15 * 60;  // Seconds
static constexpr int kFullSoc = 100;

BatteryRechargingControl::BatteryRechargingControl() {
    state_ = INACTIVE;
    recharge_soc_ = 0;
}

int BatteryRechargingControl::mapSysfsString(const char *str, struct sysfsStringEnumMap map[]) {
    for (int i = 0; map[i].s; i++)
        if (!strncmp(str, map[i].s, strlen(map[i].s)))
            return map[i].val;

    return -1;
}

BatteryStatus BatteryRechargingControl::getBatteryStatus(const char *status) {
    int ret;
    struct sysfsStringEnumMap batteryStatusMap[] = {
        {"Unknown", static_cast<int>(BatteryStatus::UNKNOWN)},
        {"Charging", static_cast<int>(BatteryStatus::CHARGING)},
        {"Discharging", static_cast<int>(BatteryStatus::DISCHARGING)},
        {"Not charging", static_cast<int>(BatteryStatus::NOT_CHARGING)},
        {"Full", static_cast<int>(BatteryStatus::FULL)},
        {NULL, 0},
    };

    ret = mapSysfsString(status, batteryStatusMap);
    if (ret < 0) {
        LOG(ERROR) << "Unknown battery status: " << status;
        return BatteryStatus::UNKNOWN;
    }

    return static_cast<BatteryStatus>(ret);
}

int64_t BatteryRechargingControl::getTime(void) {
    return nanoseconds_to_seconds(systemTime(SYSTEM_TIME_BOOTTIME));
}

int BatteryRechargingControl::RemapSOC(int soc) {
    double diff_sec = getTime() - start_time_;
    double ret_soc =
        round(soc * (diff_sec / kTransitionTime) + kFullSoc * (1 - (diff_sec / kTransitionTime)));
    LOG(INFO) << "RemapSOC: " << ret_soc;
    return ret_soc;
}

void BatteryRechargingControl::updateBatteryProperties(HealthInfo *health_info) {
    std::string charger_status;
    double elapsed_time;
    int cur_soc;

    if (!android::base::ReadFileToString(kChargerStatus, &charger_status)) {
        LOG(ERROR) << "Cannot read the charger status";
        return;
    }

    charger_status = android::base::Trim(charger_status);
    health_info->batteryStatus = getBatteryStatus(charger_status.c_str());

    if ((state_ == INACTIVE) && (health_info->batteryLevel < kFullSoc))
        return;

    LOG(INFO) << "Entry state_: " << state_ << " charger_status: " << charger_status
              << " batteryLevel: " << health_info->batteryLevel;
    switch (state_) {
        case INACTIVE:
            state_ = WAIT_EOC;
            recharge_soc_ = 0;
        case WAIT_EOC:
            if (charger_status == kStatusIsFull) {
                state_ = RECHARGING_CYCLE;
                health_info->batteryLevel = kFullSoc;
            } else if (charger_status != kStatusIsCharging) {
                // charging stopped, assume no more power source
                start_time_ = getTime();
                state_ = NO_POWER_SOURCE;
                health_info->batteryLevel = RemapSOC(health_info->batteryLevel);
            }
            break;
        case RECHARGING_CYCLE:
            if (charger_status == kStatusIsFull) {
                recharge_soc_ = 0;
                health_info->batteryLevel = kFullSoc;
                break;
            } else if (charger_status == kStatusIsCharging) {
                // Recharging cycle start.
                if (recharge_soc_ == 0) {
                    recharge_soc_ = health_info->batteryLevel;
                    health_info->batteryLevel = kFullSoc;
                } else {
                    if (health_info->batteryLevel < recharge_soc_) {
                        // overload condition
                        start_time_ = getTime();
                        state_ = OVER_LOADING;
                        health_info->batteryLevel = RemapSOC(health_info->batteryLevel);
                    } else {
                        health_info->batteryLevel = kFullSoc;
                    }
                }
            } else {
                // charging stopped, assume no more power source
                start_time_ = getTime();
                state_ = NO_POWER_SOURCE;
                health_info->batteryLevel = RemapSOC(health_info->batteryLevel);
            }
            break;
        case OVER_LOADING:
        case NO_POWER_SOURCE:
            cur_soc = health_info->batteryLevel;
            elapsed_time = getTime() - start_time_;
            if (elapsed_time > kTransitionTime) {
                LOG(INFO) << "Time is up, leave remap";
                state_ = INACTIVE;
                break;
            } else {
                LOG(INFO) << "Diff time: " << elapsed_time;
                int battery_level = RemapSOC(health_info->batteryLevel);
                if ((battery_level == health_info->batteryLevel) && (battery_level != kFullSoc)) {
                    state_ = INACTIVE;
                    break;
                }
                health_info->batteryLevel = battery_level;
            }
            if (charger_status == kStatusIsCharging) {
                if ((health_info->batteryLevel == kFullSoc) && (cur_soc >= recharge_soc_)) {
                    // When user plug in charger and the ret_soc is still 100%
                    // Change condition to Recharging cycle to avoid the SOC
                    // show lower than 100%. (Keep 100%)
                    state_ = RECHARGING_CYCLE;
                    recharge_soc_ = health_info->batteryLevel;
                }
            }
            break;
        default:
            state_ = WAIT_EOC;
            break;
    }
    LOG(INFO) << "Exit state_: " << state_ << " batteryLevel: " << health_info->batteryLevel;
}

}  // namespace health
}  // namespace crosshatch
}  // namespace google
}  // namespace device
