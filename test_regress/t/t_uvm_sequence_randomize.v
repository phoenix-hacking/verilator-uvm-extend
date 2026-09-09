// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM constrained-random items, modes, callbacks, and replay
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Test requires command line be passed uvm_pkg.sv before this filename

// verilator lint_off DECLFILENAME

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;
  import uvm_pkg::*;

  class random_meta extends uvm_object;
    `uvm_object_utils(random_meta)
    rand bit [4:0] channel;
    constraint channel_c {channel inside {[1 : 19]};}

    function new(string name = "random_meta");
      super.new(name);
    endfunction
  endclass

  class random_item extends uvm_sequence_item;
    `uvm_object_utils(random_item)
    rand bit [14:0] address;
    rand bit [7:0] tag;
    rand int unsigned length;
    rand bit [7:0] payload[];
    rand random_meta meta;
    int pre_count;
    int post_count;
    int ordinal;

    constraint address_c {
      address inside {[0 : 1020]};
      address[1:0] == 0;
    }
    constraint content_c {
      tag inside {[1 : 200]};
      length inside {[1 : 7]};
      payload.size() == length;
      foreach (payload[i]) int'(payload[i]) == ((int'(tag) + 3 * i) & 255);
      int'(meta.channel) <= length + 12;
    }

    function new(string name = "random_item");
      super.new(name);
      meta = random_meta::type_id::create("meta");
    endfunction

    function void pre_randomize();
      pre_count++;
    endfunction

    function void post_randomize();
      post_count++;
    endfunction

    function void check_content();
      if (meta == null || meta.channel < 1 || meta.channel > 19 || int'(meta.channel) > length + 12)
        `uvm_fatal("META", "Nested object constraint or allocation failed")
      if (tag < 1 || tag > 200 || length < 1 || length > 7)
        `uvm_fatal("RANGE", "Random item fields violate their constraints")
      `checkd(payload.size(), length)
      foreach (payload[i]) `checkd(int'(payload[i]), (int'(tag) + 3 * i) & 255)
    endfunction

    function int unsigned checksum();
      int unsigned value;
      value = int'(address) ^ (int'(tag) << 16) ^ (length << 8) ^ int'(meta.channel);
      foreach (payload[i]) value = (value << 5) ^ (value >> 27) ^ int'(payload[i]);
      return value;
    endfunction
  endclass

  class random_sequence extends uvm_sequence #(random_item);
    `uvm_object_utils(random_sequence)
    int completed;
    bit [255:0] seen_tags;
    bit [7:0] seen_lengths;

    function new(string name = "random_sequence");
      super.new(name);
    endfunction

    virtual task body();
      random_item item;
      random_item response;
      random_meta original_meta;
      item = random_item::type_id::create("request");
      original_meta = item.meta;
      for (int index = 0; index < 64; index++) begin
        item.ordinal = index;
        start_item(item);
        `checkd(
        item.randomize() with {
        address >= 128;
        address <= 892;
        },
        1)
        item.check_content();
        if (item.address < 128 || item.address > 892 || item.address[1:0] != 0)
          `uvm_fatal("INLINE", "Inline or declared address constraint failed")
        if (item.meta != original_meta)
          `uvm_fatal("IDENTITY", "Randomization replaced an allocated nested handle")
        `checkd(item.pre_count, index + 1)
        `checkd(item.post_count, index + 1)
        seen_tags[item.tag] = 1;
        seen_lengths[item.length] = 1;
        finish_item(item);
        get_response(response);
        `checkd(response.ordinal, index)
        `checkd(response.get_transaction_id(), item.get_transaction_id())
        completed++;
      end
      if ($countones(seen_tags) < 8 || $countones(seen_lengths) < 3)
        `uvm_fatal("VARIATION", "Constrained random traffic did not vary sufficiently")

      item.tag.rand_mode(0);
      item.length.rand_mode(0);
      item.tag = 99;
      item.length = 3;
      `checkd(item.tag.rand_mode(), 0)
      `checkd(item.length.rand_mode(), 0)
      `checkd(item.randomize(), 1)
      item.check_content();
      `checkd(item.tag, 99)
      `checkd(item.length, 3)
      item.tag.rand_mode(1);
      item.length.rand_mode(1);

      item.address_c.constraint_mode(0);
      `checkd(item.address_c.constraint_mode(), 0)
      `checkd(item.randomize() with {address == 1;}, 1)
      item.check_content();
      `checkd(item.address, 1)
      item.address_c.constraint_mode(1);
      `checkd(item.address_c.constraint_mode(), 1)
      begin
        bit [14:0] saved_address = item.address;
        bit [7:0] saved_tag = item.tag;
        int unsigned saved_length = item.length;
        bit [7:0] saved_payload[] = item.payload;
        bit [4:0] saved_channel = item.meta.channel;
        `checkd(item.randomize() with {address == 1;}, 0)
        // A failed solve preserves every random value, container shape and
        // existing nested handle; pre_randomize side effects still occur.
        `checkd(item.address, saved_address)
        `checkd(item.tag, saved_tag)
        `checkd(item.length, saved_length)
        `checkd(item.payload.size(), saved_payload.size())
        foreach (saved_payload[i]) `checkd(item.payload[i], saved_payload[i])
        if (item.meta != original_meta)
          `uvm_fatal("FAILED_STATE", "Failed solve replaced the nested object handle")
        `checkd(item.meta.channel, saved_channel)
      end
      `checkd(item.pre_count, 67)
      `checkd(item.post_count, 66)
      `checkd(item.address, 1)
      `checkd(item.randomize() with {address == 132;}, 1)
      item.check_content();
      `checkd(item.address, 132)
      `checkd(item.pre_count, 68)
      `checkd(item.post_count, 67)
      $write("UVM_RANDOM_STATE pre=%0d post=%0d failures=1\n", item.pre_count, item.post_count);
    endtask
  endclass

  class random_driver extends uvm_driver #(random_item);
    `uvm_component_utils(random_driver)
    int received;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
      forever begin
        random_item item;
        random_item response;
        seq_item_port.get_next_item(item);
        item.check_content();
        `checkd(item.ordinal, received)
        $write("UVM_RANDOM_TRACE %0d %0d %0d %0d %0d %08x\n", received, item.address, item.tag,
               item.length, item.meta.channel, item.checksum());
        #1;
        response = random_item::type_id::create("response");
        response.set_id_info(item);
        response.ordinal = received;
        received++;
        seq_item_port.item_done(response);
      end
    endtask
  endclass

  class random_test extends uvm_test;
    `uvm_component_utils(random_test)
    uvm_sequencer #(random_item) sequencer;
    random_driver driver;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = new("sequencer", this);
      driver = random_driver::type_id::create("driver", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
      random_sequence sequence_handle;
      phase.raise_objection(this);
      sequence_handle = random_sequence::type_id::create("sequence_handle");
      sequence_handle.start(sequencer);
      `checkd(sequence_handle.completed, 64)
      `checkd(driver.received, 64)
      $write("** UVM RANDOM SEQUENCE PASSED **\n");
      phase.drop_objection(this);
    endtask
  endclass

  initial begin
    run_test("random_test");
    $write("*-* All Finished *-*\n");
    $finish;
  end

  initial begin
    #1000;
    $fatal(1, "UVM random sequence timed out");
  end
endmodule
