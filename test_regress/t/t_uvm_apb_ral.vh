// -*- Verilog -*-
// DESCRIPTION: Verilator: APB register model, explicit predictor, and built-in RAL sequences
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Included inside module t after apb_sequence. Oracles follow the pinned
// Accellera UVM 2020.3.1 sources at 78c06547a2a0a29b3dc9dcafae62b75b2ff61544:
// src/reg/uvm_reg_adapter.svh (19.2.1), uvm_reg_predictor.svh (19.3),
// uvm_reg_backdoor.svh (19.5), and sequences/uvm_reg_{hw_reset,bit_bash,access}_seq.svh
// (Annex E.1-E.3). The custom backdoor is a SystemVerilog testbench mechanism;
// its acceptance does not establish uvm_hdl_* or DPI backdoor support.

class apb_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(apb_reg_adapter)

  function new(string name = "apb_reg_adapter");
    super.new(name);
    supports_byte_enable = 1;
    provides_responses = 1;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_item item = apb_item::type_id::create("register_transfer");
    if (rw.addr >= 64 || rw.addr % 4 != 0 || rw.n_bits > 32)
      `uvm_fatal("APB_RAL_ADAPTER", "register operation exceeds the APB register map")
    item.addr = 8'(rw.addr);
    item.write = rw.kind == UVM_WRITE;
    item.data = 32'(rw.data);
    item.strb = item.write ? 4'(rw.byte_en) : 4'b0;
    return item;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    apb_item item;
    if (!$cast(item, bus_item))
      `uvm_fatal("APB_RAL_ADAPTER", "adapter received an incompatible bus item")
    rw.addr = uvm_reg_addr_t'(item.addr);
    rw.kind = item.write ? UVM_WRITE : UVM_READ;
    rw.data = uvm_reg_data_t'(item.data);
    rw.n_bits = 32;
    rw.byte_en = item.write ? uvm_reg_byte_en_t'(item.strb) : '1;
    rw.status = item.error || item.abort_transfer ? UVM_NOT_OK : UVM_IS_OK;
  endfunction
endclass

class apb_ral_backdoor extends uvm_reg_backdoor;
  `uvm_object_utils(apb_ral_backdoor)

  int unsigned index;
  int reads;
  int writes;
  apb_scoreboard active_scoreboard;
  apb_scoreboard passive_scoreboard;

  function new(string name = "apb_ral_backdoor");
    super.new(name);
  endfunction

  virtual function void read_func(uvm_reg_item rw);
    if (index >= 16) `uvm_fatal("APB_RAL_BACKDOOR", "backdoor register index is outside the DUT")
    rw.set_value(uvm_reg_data_t'(dut.words[index]), 0);
    rw.set_status(UVM_IS_OK);
    reads++;
  endfunction

  virtual task read(uvm_reg_item rw);
    do_pre_read(rw);
    read_func(rw);
    do_post_read(rw);
  endtask

  virtual task write(uvm_reg_item rw);
    bit [31:0] value;
    do_pre_write(rw);
    if (index >= 16 || active_scoreboard == null || passive_scoreboard == null)
      `uvm_fatal("APB_RAL_BACKDOOR", "backdoor write is not configured")
    value = 32'(rw.get_value(0));
    dut.words[index] <= value;
    #1;
    // Notify the bus-only scoreboards of this completed sideband write using
    // the commanded value. Never derive their expected state from a DUT read.
    active_scoreboard.model[index] = value;
    passive_scoreboard.model[index] = value;
    rw.set_status(UVM_IS_OK);
    writes++;
    do_post_write(rw);
  endtask
endclass

class apb_word_reg extends uvm_reg;
  `uvm_object_utils(apb_word_reg)

  uvm_reg_field octets[4];

  function new(string name = "apb_word_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  function void build(bit [31:0] reset_value);
    foreach (octets[lane]) begin
      octets[lane] = uvm_reg_field::type_id::create($sformatf("byte_%0d", lane));
      octets[lane].configure(this, 8, lane * 8, "RW", 0, uvm_reg_data_t'(reset_value[lane*8+:8]), 1,
                             0, 1);
    end
  endfunction
endclass

class apb_reg_block extends uvm_reg_block;
  `uvm_object_utils(apb_reg_block)

  apb_word_reg words[16];
  apb_ral_backdoor backdoors[16];

  function new(string name = "apb_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  function void build();
    default_map = create_map("apb", 0, 4, UVM_LITTLE_ENDIAN, 1);
    foreach (words[i]) begin
      words[i] = apb_word_reg::type_id::create($sformatf("word_%0d", i));
      words[i].configure(this);
      words[i].build(32'ha5000000 + 32'(i));
      default_map.add_reg(words[i], uvm_reg_addr_t'(i * 4), "RW");
      backdoors[i] = apb_ral_backdoor::type_id::create($sformatf("backdoor_%0d", i));
      backdoors[i].index = i;
      words[i].set_backdoor(backdoors[i]);
    end
    lock_model();
    reset();
  endfunction
endclass

class apb_ral_predictor extends uvm_reg_predictor #(apb_item);
  `uvm_component_utils(apb_ral_predictor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void write(apb_item item);
    // Reset notifications are monitor metadata, not address-zero reads.
    if (item.reset) map.get_parent().reset();
    // The peripheral contract leaves state unchanged on an error. The bus
    // scoreboards check those responses; failed accesses must not predict.
    else if (!item.error && !item.abort_transfer) super.write(item);
  endfunction
endclass

class apb_ral_prediction_audit extends uvm_subscriber #(uvm_reg_item);
  `uvm_component_utils(apb_ral_prediction_audit)

  int reads;
  int writes;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void write(uvm_reg_item item);
    if (item.get_status() != UVM_IS_OK || item.get_element_kind() != UVM_REG)
      `uvm_fatal("APB_RAL_PREDICTOR", "predictor emitted an invalid register operation")
    if (item.get_kind() == UVM_WRITE) writes++;
    else reads++;
  endfunction
endclass

class apb_ral_external_sequence extends apb_sequence;
  `uvm_object_utils(apb_ral_external_sequence)

  function new(string name = "apb_ral_external_sequence");
    super.new(name);
  endfunction

  virtual task body();
    for (int i = 0; i < 16; i++) begin
      transfer(1, 8'(i * 4), 32'h13579bdf ^ (32'(i) * 32'h01010101), 4'(i));
      transfer(0, 8'(i * 4));
    end
  endtask
endclass

class apb_ral_helper extends uvm_component;
  `uvm_component_utils(apb_ral_helper)

  apb_reg_block model;
  apb_reg_adapter adapter;
  apb_ral_predictor predictor;
  apb_ral_prediction_audit predictions;
  uvm_sequencer #(apb_item) sequencer;
  apb_driver driver;
  int completed;
  int reads;
  int writes;
  int resets;
  int backdoor_reads;
  int backdoor_writes;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    model = apb_reg_block::type_id::create("model");
    model.build();
    adapter = apb_reg_adapter::type_id::create("adapter");
    predictor = apb_ral_predictor::type_id::create("predictor", this);
    predictions = apb_ral_prediction_audit::type_id::create("predictions", this);
  endfunction

  function void attach(apb_agent active_agent, apb_agent passive_agent,
                       apb_scoreboard active_scoreboard, apb_scoreboard passive_scoreboard);
    driver = active_agent.driver;
    sequencer = active_agent.sequencer;
    model.default_map.set_sequencer(sequencer, adapter);
    model.default_map.set_auto_predict(0);
    model.default_map.set_check_on_read(1);
    predictor.map = model.default_map;
    predictor.adapter = adapter;
    passive_agent.monitor.observed.connect(predictor.bus_in);
    predictor.reg_ap.connect(predictions.analysis_export);
    foreach (model.backdoors[i]) begin
      model.backdoors[i].active_scoreboard = active_scoreboard;
      model.backdoors[i].passive_scoreboard = passive_scoreboard;
    end
  endfunction

  function void require_status(uvm_status_e status, string operation);
    if (status != UVM_IS_OK)
      `uvm_fatal("APB_RAL_STATUS", $sformatf("%s returned %s", operation, status.name()))
  endfunction

  function void require_value(uvm_reg_data_t actual, bit [31:0] expected, string operation);
    if (actual !== uvm_reg_data_t'(expected))
      `uvm_fatal("APB_RAL_VALUE", $sformatf("%s got=%0h expected=%0h", operation, actual, expected))
  endfunction

  task require_counts(int before_reads, int before_writes, int expected_reads, int expected_writes,
                      string operation);
    #1;
    if (predictions.reads - before_reads != expected_reads
        || predictions.writes - before_writes != expected_writes)
      `uvm_fatal("APB_RAL_COUNT", $sformatf(
                 "%s read delta=%0d write delta=%0d expected=%0d/%0d",
                 operation,
                 predictions.reads - before_reads,
                 predictions.writes - before_writes,
                 expected_reads,
                 expected_writes
                 ))
  endtask

  task reset_hardware();
    driver.reset_bus();
    model.reset();
    resets++;
  endtask

  task run_checks();
    uvm_reg_hw_reset_seq reset_seq;
    uvm_reg_bit_bash_seq bit_bash_seq;
    uvm_reg_access_seq access_seq;
    apb_ral_external_sequence external_seq;
    uvm_status_e status;
    uvm_reg_data_t value;
    bit [31:0] expected[16];
    int initial_reads;
    int initial_writes;
    int stage_reads;
    int stage_writes;
    int initial_driver_completed;

    if (driver == null || sequencer == null || model.default_map.get_auto_predict())
      `uvm_fatal("APB_RAL_CONFIG", "RAL transport or explicit prediction is not configured")
    #1;
    initial_reads = predictions.reads;
    initial_writes = predictions.writes;
    initial_driver_completed = driver.completed;
    reset_hardware();
    reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
    reset_seq.model = model;
    reset_seq.start(null);
    require_counts(initial_reads, initial_writes, 16, 0, "built-in reset");
    foreach (expected[i])
      require_value(model.words[i].get_mirrored_value(), 32'ha5000000 + 32'(i), "reset mirror");

    stage_reads = predictions.reads;
    stage_writes = predictions.writes;
    foreach (expected[i]) begin
      expected[i] = 32'h10203040 ^ (32'(i) * 32'h01010101);
      model.words[i].write(status, uvm_reg_data_t'(expected[i]), UVM_FRONTDOOR);
      require_status(status, "frontdoor write");
      #1;
      require_value(model.words[i].get_mirrored_value(), expected[i], "write prediction");
      model.words[i].read(status, value, UVM_FRONTDOOR);
      require_status(status, "frontdoor read");
      require_value(value, expected[i], "frontdoor read");

      model.words[i].set(uvm_reg_data_t'(expected[i]) ^ uvm_reg_data_t'(32'h55aa33cc));
      require_value(model.words[i].get_mirrored_value(), expected[i], "set must not alter mirror");
      expected[i] ^= 32'h55aa33cc;
      require_value(model.words[i].get(), expected[i], "desired value");
      if (!model.words[i].needs_update())
        `uvm_fatal("APB_RAL_UPDATE", "set did not require a hardware update")
      model.words[i].update(status, UVM_FRONTDOOR);
      require_status(status, "frontdoor update");
      #1;
      if (model.words[i].needs_update())
        `uvm_fatal("APB_RAL_UPDATE", "completed update did not synchronize the mirror")
      model.words[i].mirror(status, UVM_CHECK, UVM_FRONTDOOR);
      require_status(status, "frontdoor mirror");
      require_value(model.words[i].get_mirrored_value(), expected[i], "updated mirror");

      // Each byte is individually accessible; the adapter must emit a single
      // byte-enable write preserving all three neighboring bytes.
      for (int lane = 0; lane < 4; lane++) begin
        bit [7:0] octet = 8'(64 + i * 4 + lane);
        model.words[i].octets[lane].write(status, uvm_reg_data_t'(octet), UVM_FRONTDOOR);
        require_status(status, "byte-enable field write");
        expected[i][lane*8+:8] = octet;
        #1;
        require_value(model.words[i].get_mirrored_value(), expected[i], "byte-enable prediction");
      end
      model.words[i].mirror(status, UVM_CHECK, UVM_FRONTDOOR);
      require_status(status, "byte-enable mirror");
    end
    require_counts(stage_reads, stage_writes, 48, 96, "frontdoor and byte-enable operations");

    stage_reads = predictions.reads;
    stage_writes = predictions.writes;
    external_seq = apb_ral_external_sequence::type_id::create("external_seq");
    external_seq.start(sequencer);
    require_counts(stage_reads, stage_writes, 16, 16, "external bus prediction");
    if (external_seq.completed != 32)
      `uvm_fatal("APB_RAL_COUNT", "external bus sequence did not complete every operation")
    foreach (expected[i]) begin
      bit [31:0] mask = 0;
      bit [31:0] data = 32'h13579bdf ^ (32'(i) * 32'h01010101);
      for (int lane = 0; lane < 4; lane++) if ((i & (1 << lane)) != 0) mask |= 32'hff << (lane * 8);
      expected[i] = (expected[i] & ~mask) | (data & mask);
      require_value(model.words[i].get_mirrored_value(), expected[i],
                    "out-of-band write prediction");
    end

    reset_hardware();
    stage_reads = predictions.reads;
    stage_writes = predictions.writes;
    bit_bash_seq = uvm_reg_bit_bash_seq::type_id::create("bit_bash_seq");
    bit_bash_seq.model = model;
    bit_bash_seq.start(null);
    require_counts(stage_reads, stage_writes, 1024, 1024, "built-in bit bash");
    foreach (expected[i])
      require_value(model.words[i].get_mirrored_value(), 32'ha5000000 + 32'(i),
                    "bit-bash final mirror");

    reset_hardware();
    stage_reads = predictions.reads;
    stage_writes = predictions.writes;
    access_seq = uvm_reg_access_seq::type_id::create("access_seq");
    access_seq.model = model;
    access_seq.start(null);
    require_counts(stage_reads, stage_writes, 16, 16, "built-in access");
    foreach (expected[i]) begin
      require_value(model.words[i].get_mirrored_value(), 32'ha5000000 + 32'(i),
                    "access final mirror");
      if (model.backdoors[i].reads != 2 || model.backdoors[i].writes != 1)
        `uvm_fatal("APB_RAL_COUNT", "built-in access skipped a register backdoor operation")
      backdoor_reads += model.backdoors[i].reads;
      backdoor_writes += model.backdoors[i].writes;
    end

    reads = predictions.reads - initial_reads;
    writes = predictions.writes - initial_writes;
    completed = driver.completed - initial_driver_completed;
    if (reads != 1120 || writes != 1152 || completed != 2272 || resets != 3
        || backdoor_reads != 32 || backdoor_writes != 16)
      `uvm_fatal("APB_RAL_COUNT", "RAL aggregate operation counts are incorrect")
    $display(
        "APB_RAL_SENTINEL registers=16 reads=%0d writes=%0d resets=%0d backdoor_reads=%0d backdoor_writes=%0d",
        reads, writes, resets, backdoor_reads, backdoor_writes);
  endtask
endclass
