# Radio instance declarations for v5e (Semtech USP path).
# Included by instances.fpp inside module ReferenceDeployment { }.
# Selected by CMakeLists.txt when CONFIG_LORA_BASICS_MODEM_DRIVERS is set.
#
# UspRadio is an ACTIVE component (deferred-handler pattern), unlike the
# passive Zephyr::LoRa it replaces -- needs its own queue/stack/priority.
# Priority 11 is intentionally above every other active component in this
# topology (rateGroup100Hz/10Hz priority 3, rateGroup1Hz priority 4,
# fileManager/prmDb/byteComBridge priority 5, fileUplink priority 6,
# cmdSeq priority 7), matching proves-core-reference's RadioInstances_Usp.fppi
# convention.

  instance uspRadio: Zephyr.UspRadio base id 0x10017000 \
    queue size Default.QUEUE_SIZE * 2 \
    stack size Default.STACK_SIZE \
    priority 11
