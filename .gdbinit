
# Vibed
define zstacks
  set $fill8 = 0xaa
  set $fill32 = 0xaaaaaaaa
  set $t = _kernel.threads

  printf "%-18s %-22s %-6s %-8s %-14s %-14s %-8s %-8s %-7s\n", \
    "THREAD", "NAME", "PRIO", "STATE", "START", "END", "SIZE", "USED", "USED%"

  while $t
    set $start = (unsigned char *)$t->stack_info.start
    set $size = (unsigned long)$t->stack_info.size
    set $end = $start + $size

    set $unused = 0

    # Fast path: scan 4 bytes at a time.
    while (($unused + 4) <= $size) && (*(unsigned int *)($start + $unused) == $fill32)
      set $unused = $unused + 4
    end

    # Finish exact byte count.
    while ($unused < $size) && (*(unsigned char *)($start + $unused) == $fill8)
      set $unused = $unused + 1
    end

    set $used = $size - $unused

    if $size
      set $pct = ($used * 100) / $size
    else
      set $pct = 0
    end

    printf "%-18p %-22s %-6d 0x%-6x %-14p %-14p %-8lu %-8lu %-6lu%%\n", \
      $t, \
      $t->name, \
      $t->base.prio, \
      $t->base.thread_state, \
      $start, \
      $end, \
      $size, \
      $used, \
      $pct

    set $t = $t->next_thread
  end
end

document zstacks
Print high-water stack usage for all Zephyr threads.
Requires CONFIG_THREAD_STACK_INFO=y, CONFIG_INIT_STACKS=y, CONFIG_THREAD_MONITOR=y, CONFIG_THREAD_NAME=y.
Scans 0xaa stack-fill words, so it reports high-water usage, not live SP usage.
end

# Vibed
define zthreads
  set $t = _kernel.threads
  printf "%-18s %-18s %-8s %-8s %-18s %-18s %-10s\n", "THREAD", "NAME", "PRIO", "STATE", "STACK_START", "STACK_END", "SIZE"

  while $t
    set $stack_start = $t->stack_info.start
    set $stack_end = (char *)$t->stack_info.start + $t->stack_info.size

    if $t->name[0]
      printf "%-18p %-18s %-8d 0x%-6x %-18p %-18p %-10u\n", \
        $t, $t->name, $t->base.prio, $t->base.thread_state, \
        $stack_start, $stack_end, $t->stack_info.size
    else
      printf "%-18p %-18s %-8d 0x%-6x %-18p %-18p %-10u\n", \
        $t, "<noname>", $t->base.prio, $t->base.thread_state, \
        $stack_start, $stack_end, $t->stack_info.size
    end

    set $t = $t->next_thread
  end
end

document zthreads
Print all Zephyr threads with priority, state, and stack bounds.
Requires CONFIG_THREAD_STACK_INFO=y.
end

file build-artifacts/zephyr.elf

# ctd = current thread
macro define ctd _kernel.cpus[0].current
