// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;

  // String-key associative array with size constraint
  class StringKeyTest;
    rand int data[string];
    constraint c_size {data.size() == 3;}
  endclass

  // Int-key associative array with size constraint
  class IntKeyTest;
    rand bit [7:0] values[int];
    constraint c_size {values.size() == 2;}
  endclass

`ifdef ASSOC_SIZE_EXPANDED
  class SizeBase #(
      type KEY = int
  );
    typedef bit [64:0] value_t;
    rand value_t data[KEY];
    rand bit [6:0] count_mirror;
    int wanted;

    function int identity(input int count);
      return count;
    endfunction

    constraint c_size {
      data.size() == wanted;
      int'(count_mirror) == data.num();
      identity(data.size()) == wanted;
    }
  endclass

  class SizeDerived extends SizeBase #(int);
  endclass

  class ElementTest;
    rand bit [6:0] data[int];
    int wanted;
    bit rebuild;
    constraint c_size {data.size() == wanted;}
    constraint c_values {foreach (data[k]) data[k] == 7'(k + 64);}

    function void pre_randomize();
      if (rebuild) begin
        data.delete();
        for (int k = 0; k < wanted; ++k) data[k-9] = 0;
      end
    endfunction
  endclass

  class ElementDerived extends ElementTest;
  endclass

  typedef bit [14:0] entries_t[int];
  typedef struct {entries_t data;} wrapper_t;

  class SelectionTest;
    rand entries_t fixed_arrays[3:1];
    rand entries_t dynamic_arrays[];
    rand entries_t queue_arrays[$];
    rand entries_t assoc_arrays[int];
    rand wrapper_t wrapped;
    rand bit [6:0] count_mirror;
    int index;

    constraint c_size {
      int'(count_mirror) == fixed_arrays[index].size() + dynamic_arrays[index].num() +
          queue_arrays[index].size() + assoc_arrays[index].num() + wrapped.data.size() +
          copy_entries().num();
    }

    function entries_t copy_entries();
      return wrapped.data;
    endfunction

    function new();
      entries_t empty_entries;
      dynamic_arrays = new[4];
      repeat (4) queue_arrays.push_back(empty_entries);
    endfunction
  endclass

  class EmptyTest;
    rand bit [14:0] dynamic_values[];
    rand bit [64:0] queue_values[$];
    constraint c_values {
      foreach (dynamic_values[k]) dynamic_values[k] == 15'(k);
      foreach (queue_values[k]) queue_values[k] == 65'(k);
    }
  endclass
`endif

  initial begin
    automatic StringKeyTest str_obj = new();
    automatic IntKeyTest int_obj = new();
    automatic int rand_ok;

    // String-key: pre-populate 3 entries to match constraint
    str_obj.data["x"] = 0;
    str_obj.data["y"] = 0;
    str_obj.data["z"] = 0;

    rand_ok = str_obj.randomize();
    `checkd(rand_ok, 1);
    `checkd(str_obj.data.size(), 3);

    // Int-key: pre-populate 2 entries to match constraint
    int_obj.values[10] = 0;
    int_obj.values[20] = 0;

    rand_ok = int_obj.randomize();
    `checkd(rand_ok, 1);
    `checkd(int_obj.values.size(), 2);

`ifdef ASSOC_SIZE_EXPANDED
    begin
      automatic SizeDerived numeric_obj = new;
      automatic SizeBase #(string) string_obj = new;
      automatic ElementTest element_obj = new;
      automatic ElementDerived derived_obj = new;
      automatic SelectionTest selection_obj = new;
      automatic EmptyTest empty_obj = new;
      int wanted;

      // Size is determined by existing keys, even when other variables are solved.
      for (int count = 0; count < 5; ++count) begin
        numeric_obj.data.delete();
        string_obj.data.delete();
        element_obj.data.delete();
        for (int k = 0; k < count; ++k) begin
          numeric_obj.data[k-7] = 0;
          string_obj.data[$sformatf("key%0d", k)] = 0;
          element_obj.data[k-7] = 0;
        end
        numeric_obj.wanted = count;
        string_obj.wanted = count;
        element_obj.wanted = count;
        rand_ok = numeric_obj.randomize();
        `checkd(rand_ok, 1);
        `checkd(numeric_obj.count_mirror, 7'(count));
        rand_ok = string_obj.randomize();
        `checkd(rand_ok, 1);
        `checkd(string_obj.count_mirror, 7'(count));
        rand_ok = element_obj.randomize();
        `checkd(rand_ok, 1);
        foreach (element_obj.data[k]) begin
          `checkd(element_obj.data[k], 7'(k + 64));
        end

        numeric_obj.wanted = count + 1;
        string_obj.wanted = count + 1;
        rand_ok = numeric_obj.randomize();
        `checkd(rand_ok, 0);
        rand_ok = string_obj.randomize();
        `checkd(rand_ok, 0);
        `checkd(numeric_obj.data.size(), count);
        `checkd(string_obj.data.num(), count);
        for (int k = 0; k < count; ++k) begin
          `checkd(numeric_obj.data.exists(k - 7), 1);
          `checkd(string_obj.data.exists($sformatf("key%0d", k)), 1);
        end

        numeric_obj.c_size.constraint_mode(0);
        wanted = count;
        rand_ok = numeric_obj.randomize() with {numeric_obj.data.size() == local:: wanted;};
        `checkd(rand_ok, 1);
        ++wanted;
        rand_ok = numeric_obj.randomize() with {numeric_obj.data.num() == local:: wanted;};
        `checkd(rand_ok, 0);
        `checkd(numeric_obj.data.size(), count);
        numeric_obj.c_size.constraint_mode(1);
      end

      // Refresh inherited element bindings after callbacks, including shrinking to empty.
      derived_obj.rebuild = 1;
      for (int count = 4; count >= 0; --count) begin
        derived_obj.wanted = count;
        rand_ok = derived_obj.randomize();
        `checkd(rand_ok, 1);
        `checkd(derived_obj.data.size(), count);
        foreach (derived_obj.data[k]) `checkd(derived_obj.data[k], 7'(k + 64));
        rand_ok = empty_obj.randomize();
        `checkd(rand_ok, 1);
        `checkd(empty_obj.dynamic_values.size(), 0);
        `checkd(empty_obj.queue_values.size(), 0);
      end

      // Existing sizes can be selected through fixed, dynamic, queue, and associative indexes.
      for (int index = 1; index <= 3; ++index) begin
        selection_obj.index = index;
        selection_obj.wrapped.data[index] = 0;
        for (int k = 0; k < index; ++k) begin
          selection_obj.fixed_arrays[index][k] = 0;
          selection_obj.dynamic_arrays[index][k] = 0;
          selection_obj.queue_arrays[index][k] = 0;
          selection_obj.assoc_arrays[index][k] = 0;
        end
        rand_ok = selection_obj.randomize();
        `checkd(rand_ok, 1);
        `checkd(selection_obj.count_mirror, 7'(6 * index));
      end

      // Disabling randomization does not change the existing size predicate.
      str_obj.data.rand_mode(0);
      str_obj.data.delete("z");
      rand_ok = str_obj.randomize();
      `checkd(rand_ok, 0);
      `checkd(str_obj.data.size(), 2);
      str_obj.c_size.constraint_mode(0);
      wanted = 2;
      rand_ok = str_obj.randomize() with {data.size() == local:: wanted;};
      `checkd(rand_ok, 1);
      wanted = 3;
      rand_ok = str_obj.randomize() with {data.num() == local:: wanted;};
      `checkd(rand_ok, 0);

      // Explicit scope randomization also treats associative size as current state.
      wanted = 2;
      rand_ok = std::randomize(str_obj.data) with {str_obj.data.size() == wanted;};
      `checkd(rand_ok, 1);
      wanted = 3;
      rand_ok = std::randomize(str_obj.data) with {str_obj.data.num() == wanted;};
      `checkd(rand_ok, 0);
      `checkd(str_obj.data.size(), 2);
    end
`endif

    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
