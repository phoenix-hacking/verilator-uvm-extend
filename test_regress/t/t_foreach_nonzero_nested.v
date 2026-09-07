// -*- Verilog -*-
// DESCRIPTION: Verilator: Nested foreach selects each parent dimension
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t;
  typedef int queue_t[$];
  typedef int dynamic_t[];
  typedef int associative_t[int];
  typedef queue_t queue_rows_t[2:4];
  typedef string text_rows_t[-1:-3];

  class holder;
    queue_t rows[2:4];
    function void check(int epoch);
      int visits = 0;
      foreach (rows[i]) begin
        rows[i].delete();
        for (int j = 0; j < i; j++) rows[i].push_back(epoch * 1000 + i * 100 + j);
      end
      foreach (rows[i, j]) begin
        `checkd(rows[i][j], epoch * 1000 + i * 100 + j)
        visits++;
      end
      `checkd(visits, 9)
    endfunction
  endclass

  queue_t ascending[2:4];
  dynamic_t descending[-2:-4];
  queue_t deep[-1:1][5:3];
  associative_t keyed[3:1];
  string texts[2:4];
  queue_rows_t mixed[];
  text_rows_t text_map[string];
  holder item;

  initial begin
    int visits;
    int expected_visits;
    item = new;
    for (int epoch = 0; epoch < 4; epoch++) begin
      visits = 0;
      foreach (ascending[i]) begin
        ascending[i].delete();
        for (int j = 0; j < i; j++) ascending[i].push_back(epoch * 1000 + i * 100 + j);
      end
      foreach (ascending[i, j]) begin
        `checkd(ascending[i][j], epoch * 1000 + i * 100 + j)
        visits++;
      end
      `checkd(visits, 9)

      visits = 0;
      foreach (descending[i]) begin
        descending[i] = new[-i - 2];
        for (int j = 0; j < -i - 2; j++) descending[i][j] = epoch * 1000 + i * 100 + j;
      end
      foreach (descending[i, j]) begin
        `checkd(descending[i][j], epoch * 1000 + i * 100 + j)
        visits++;
      end
      `checkd(visits, 3)

      visits = 0;
      expected_visits = 0;
      foreach (deep[i, j]) begin
        deep[i][j].delete();
        for (int k = 0; k < i + j + epoch - 2; k++) begin
          deep[i][j].push_back(epoch * 1000 + i * 100 + j * 10 + k);
          expected_visits++;
        end
      end
      foreach (deep[i, j, k]) begin
        `checkd(deep[i][j][k], epoch * 1000 + i * 100 + j * 10 + k)
        visits++;
      end
      `checkd(visits, expected_visits)

      // Dynamic outer dimensions must retain the selected fixed array's type.
      mixed = new[2];
      for (int i = 0; i < 2; i++) begin
        for (int j = 2; j <= 4; j++) begin
          mixed[i][j].delete();
          for (int k = 0; k < i + j - 2 + epoch; k++)
          mixed[i][j].push_back(epoch * 1000 + i * 100 + j * 10 + k);
        end
      end
      visits = 0;
      foreach (mixed[i, j, k]) begin
        `checkd(mixed[i][j][k], epoch * 1000 + i * 100 + j * 10 + k)
        visits++;
      end
      `checkd(visits, 9 + 6 * epoch)

      visits = 0;
      foreach (keyed[i]) begin
        keyed[i].delete();
        keyed[i][-i] = epoch * 1000 - i;
        keyed[i][i+7] = epoch * 1000 + i + 7;
      end
      foreach (keyed[i, key]) begin
        `checkd(keyed[i][key], epoch * 1000 + key)
        visits++;
      end
      `checkd(visits, 6)

      texts[2] = "ab";
      texts[3] = "";
      texts[4] = "abcd";
      visits = 0;
      foreach (texts[i, j]) begin
        `checkd(texts[i].getc(j), 8'(97 + j))
        visits++;
      end
      `checkd(visits, 6)

      // Associative selection followed by a fixed dimension and string length.
      text_map["first"][-1] = "ab";
      text_map["first"][-2] = "";
      text_map["first"][-3] = "abc";
      text_map["second"][-1] = "";
      text_map["second"][-2] = "a";
      text_map["second"][-3] = "abcd";
      visits = 0;
      foreach (text_map[key, i, j]) begin
        `checkd(text_map[key][i].getc(j), 8'(97 + j))
        visits++;
      end
      `checkd(visits, 10)
      item.check(epoch);
    end
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
