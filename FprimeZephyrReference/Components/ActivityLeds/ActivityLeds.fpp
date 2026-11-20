module Components {

  @ Drives the board's status LEDs from the devicetree aliases heartbeat-led and activity-led.
  @ heartbeat-led blinks while the rate groups run. activity-led is lit while the radio
  @ transmits and blinks once for each radio interrupt while receiving.
  passive component ActivityLeds {

    @ Called by the 100 Hz rate group
    sync input port run: Svc.Sched

  }

}
