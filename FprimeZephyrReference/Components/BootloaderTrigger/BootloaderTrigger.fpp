module Components {

  @ Reboots the board into its ROM USB bootloader so a host can reflash it
  @ with no button presses. Entry takes ARM_BOOTLOADER then TRIGGER_BOOTLOADER
  @ within BOOTLOADER_ARM_WINDOW_S seconds, both carrying the board's key: the
  @ last 8 hex digits of its USB serial number.
  passive component BootloaderTrigger {

    @ Seconds TRIGGER_BOOTLOADER stays allowed after ARM_BOOTLOADER
    constant BOOTLOADER_ARM_WINDOW_S = 30

    @ First step: opens the arm window
    sync command ARM_BOOTLOADER(key: U32)

    @ Second step: reboot into the ROM USB bootloader (BOOTSEL)
    sync command TRIGGER_BOOTLOADER(key: U32)

    @ TRIGGER_BOOTLOADER is allowed for the next window_s seconds
    event BootloaderArmed(window_s: U32) \
      severity activity high \
      format "Bootloader entry armed for {} s; send TRIGGER_BOOTLOADER to reboot into BOOTSEL"

    @ A bootloader command carried another board's key
    event BootloaderKeyRejected(key: U32, expected: U32) \
      severity warning low \
      format "Bootloader command rejected: key 0x{x} is not this board's 0x{x}"

    @ TRIGGER_BOOTLOADER arrived without a live arm
    event BootloaderNotArmed() \
      severity warning low \
      format "TRIGGER_BOOTLOADER rejected: send ARM_BOOTLOADER first"

    @ Rebooting into the ROM bootloader now
    event EnteringBootloader() \
      severity activity high \
      format "Rebooting into the ROM USB bootloader"

    @ This board has no remote bootloader entry
    event BootloaderUnsupported() \
      severity warning low \
      format "This board cannot enter its bootloader remotely"

    ##########################################################
    # Standard AC Ports: Required for Commands, and Events   #
    ##########################################################
    @ Port for requesting the current time
    time get port timeCaller

    @ Port for sending command registrations
    command reg port cmdRegOut

    @ Port for receiving commands
    command recv port cmdIn

    @ Port for sending command responses
    command resp port cmdResponseOut

    @ Port for sending textual representation of events
    text event port logTextOut

    @ Port for sending events to downlink
    event port logOut
  }

}
