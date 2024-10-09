#!/bin/bash


# Check total amount of SWAP being used and free swap
# if swap usage is higher than X start to clean up, otherwise exit
# if free + available memory is higher than 150% SWAP usage, then swapoff/on
# if free + available is not higher than 150% SWAP usage, check buffer to see if is possible to clean-up buffer and then swapoff/on
# if still not possible to cleanup SWAP, exit and send a notification

# SET SAFE VALUE FOR SWAP
SWAP_MAX_USE=75

swap_cleanup() {
    logger "SWAP-CLEANER: Starting to clean up SWAP"

    logger "SWAP-CLEANER: Running swapoff -a"
    swapoff=$(swapoff -a)
    swapoff_sc=$?

    # bring swap back - even if swapoff fails it should try to bring it back
    logger "SWAP-CLEANER: Running swapon -a"
    swapon=$(swapon -a)
    swapon_sc=$?

    if [ $swapoff_sc -ne 0 ]; then
        logger "SWAP-CLEANER: Fail to run 'swapoff -a' with error code $swapoff_sc and mesage: '$swapoff'"
        exit 1
    fi

    if [ $swapon_sc -ne 0 ]; then
        logger "SWAP-CLEANER: Fail to run 'swapon -a' with error code $swapon_sc and mesage: '$swapon'"
        exit 1
    fi
}

# Get the total and used SWAP memory
swap_total=$(free | awk '/Swap:/ {print $2}')
swap_used=$(free | awk '/Swap:/ {print $3}')

# Calculate the SWAP usage percentage
swap_usage=$(awk "BEGIN { printf \"%.2f\", ($swap_used / $swap_total) * 100 }")

# Check if SWAP usage is higher than SWAP_MAX_USE
if (( $(echo "$swap_usage >= $SWAP_MAX_USE" | bc -l) )); then

    logger "SWAP-CLEANER: Swap usage is $swap_usage%, starting the process to clean up"

    # Get the total and available RAM memory
    ram_total=$(free | awk '/Mem:/ {print $2}')
    ram_available=$(free | awk '/Mem:/ {print $7}')
    ram_free=$(free | awk '/Mem:/ {print $4}')
    ram_cache=$(free | awk '/Mem:/ {print $6}')

    logger "SWAP-CLEANER: Information Before Running total ammount of RAM: $ram_total, Available: $ram_available, Free: $ram_free, Cache/Buffer: $ram_cache"

    # Calculate the total free RAM available for swap cleanup
    ram_free_to_use=$((ram_available + ram_free))

    # Check if available RAM is 150% higher than SWAP used
    # if (( $(echo "$ram_free_to_use > ($swap_used * 1.50 )" | bc -l) )); then
    #     swap_cleanup
    if (( $(echo "($ram_free_to_use + $ram_cache) > ($swap_used * 1.50)" | bc -l ) )); then
        logger "SWAP-CLEANER: Dropping caches to get space for RAM cleanup"
        sync
        echo 1 > /proc/sys/vm/drop_caches
        swap_cleanup
        logger "SWAP-CLEANER: Information After Clean-Up. Total ammount of RAM: $ram_total, Available: $ram_available, Free: $ram_free, Cache/Buffer: $ram_cache"
    else
        logger "SWAP-CLEANER: SWAP usage is high, but there is no enough available RAM to clean up SWAP."
        exit 1
    fi
else
    logger "SWAP-CLEANER: Exiting Swap cleaner. Current usage is $swap_usage%, while the threshold is $SWAP_MAX_USE%"
    exit 0
fi
