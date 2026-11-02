-- Lab06 combined self-checking testbench (game FSM + key conditioner).
-- Simulation only. No std.env/stop: clock stops itself when both tests finish.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity lab06_tb is end;
architecture test of lab06_tb is
  constant T : time := 20 ns;
  signal clk : std_logic := '0';
  signal game_done, key_done : std_logic := '0';
  signal krst, kraw, kpulse, kstable : std_logic := '0';
  signal pulses_seen : integer := 0;
  signal rst, start : std_logic := '0';
  signal press : std_logic_vector(2 downto 0) := "000";
  signal leds : std_logic_vector(2 downto 0);
  signal score : std_logic_vector(3 downto 0);
  signal status : std_logic_vector(1 downto 0);
  signal state, showidx, inputidx : std_logic_vector(2 downto 0);
  type seq_t is array(0 to 6) of std_logic_vector(2 downto 0);
begin
  clk_gen: process
  begin
    while game_done = '0' or key_done = '0' loop
      clk <= '0'; wait for T/2;
      clk <= '1'; wait for T/2;
    end loop;
    wait;
  end process;

  key_dut: entity work.key_conditioner(rtl)
    generic map(G_STABLE_CYCLES => 3)
    port map(clk_i => clk, rst_i => krst, raw_pressed_i => kraw,
             press_pulse_o => kpulse, stable_pressed_o => kstable);

  key_count: process(clk)
  begin
    if rising_edge(clk) then
      if kpulse = '1' then pulses_seen <= pulses_seen + 1; end if;
    end if;
  end process;

  key_test: process
    procedure ktick is
    begin wait until rising_edge(clk); wait for 1 ns; end procedure;
  begin
    krst <= '1'; ktick; ktick; krst <= '0'; ktick;
    kraw <= '1'; ktick; kraw <= '0'; ktick;
    kraw <= '1'; ktick; kraw <= '0'; ktick;
    for i in 1 to 5 loop ktick; end loop;
    assert kstable = '0' and pulses_seen = 0
      report "Short bounce was incorrectly accepted" severity failure;
    kraw <= '1';
    for i in 1 to 10 loop ktick; end loop;
    assert kstable = '1' and pulses_seen = 1
      report "Long press should produce one pulse" severity failure;
    for i in 1 to 8 loop ktick; end loop;
    assert pulses_seen = 1 report "Holding a key repeated event" severity failure;
    kraw <= '0';
    for i in 1 to 10 loop ktick; end loop;
    assert kstable = '0' and pulses_seen = 1
      report "Release unexpectedly produced another press event" severity failure;
    report "PASS: key conditioner (bounce rejected, one pulse per press)" severity note;
    key_done <= '1';
    wait;
  end process;
  dut: entity work.lab06_game(rtl)
    generic map(G_OFF_TICKS => 3, G_SHOW_TICKS => 4)
    port map(clk_i => clk, rst_i => rst, start_i => start, press_i => press,
      leds_o => leds, score_o => score, status_o => status, state_o => state,
      show_idx_o => showidx, input_idx_o => inputidx);

  test: process
    variable seq : seq_t;
    variable original_prefix : seq_t;
    variable first_game_first : std_logic_vector(2 downto 0) := "000";
    variable captured, cycles : integer;
    variable last_led : std_logic_vector(2 downto 0);
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure;
    procedure begin_game is
    begin
      start <= '1'; tick;
      start <= '0'; tick;
    end procedure;
    procedure send_press(constant choice : in std_logic_vector(2 downto 0)) is
    begin
      press <= choice; tick;
      press <= "000"; tick;
    end procedure;
    procedure watch_round(
      constant required_count : in integer;
      variable seen : out seq_t
    ) is
      variable got : integer := 0;
      variable spent : integer := 0;
      variable prev : std_logic_vector(2 downto 0) := "000";
    begin
      while state /= "011" loop
        assert spent < 300 report "TIMEOUT: game did not enter WAIT_PLAYER" severity failure;
        if leds /= "000" and prev = "000" then
          assert got < required_count report "EXTRA symbol displayed" severity failure;
          assert leds = "001" or leds = "010" or leds = "100"
            report "LED display is not one-hot" severity failure;
          seen(got) := leds;
          got := got + 1;
        end if;
        prev := leds;
        tick;
        spent := spent + 1;
      end loop;
      assert got = required_count report "Wrong number of pattern blinks" severity failure;
      assert to_integer(unsigned(score)) = required_count
        report "Score/round length mismatch" severity failure;
      assert leds = "000" report "LED must be off in input phase" severity failure;
    end procedure;
  begin
    rst <= '1'; tick; tick; rst <= '0'; tick;
    assert state = "000" report "RESET failed" severity failure;
    begin_game;

    -- Success scenario: complete every round 1..7, replay the entire prefix.
    for r in 1 to 7 loop
      watch_round(r, seq);
      if r = 1 then first_game_first := seq(0); end if;
      if r > 1 then
        for k in 0 to r - 2 loop
          assert seq(k) = original_prefix(k)
            report "Pattern prefix changed between rounds" severity failure;
        end loop;
      end if;
      for k in 0 to r - 1 loop original_prefix(k) := seq(k); end loop;
      report "PASS: showing round " & integer'image(r) severity note;
      for i in 0 to r-1 loop
        send_press(seq(i));
      end loop;
      if r < 7 then
        assert state = "001" report "Did not advance to next round" severity failure;
      end if;
    end loop;
    assert state = "100" and status = "10"
      report "WIN condition failed after seven correct rounds" severity failure;
    report "PASS: seven-round victory and A status" severity note;

    -- Replay must create a new pattern; first symbol changes deterministically.
    begin_game;
    watch_round(1, seq);
    assert seq(0) /= first_game_first
      report "Replay did not change the pattern" severity failure;
    report "PASS: replay produced a different pattern" severity note;
    if seq(0) = "001" then send_press("010");
    else send_press("001"); end if;
    assert state = "101" and status = "01"
      report "LOSE status was not reached after wrong key" severity failure;
    report "PASS: wrong key triggers F status" severity note;

    -- Multi-key input is invalid and must also lose.
    begin_game;
    watch_round(1, seq);
    send_press("011");
    assert state = "101" report "Multiple simultaneous keys not rejected" severity failure;
    report "PASS: multi-key input rejected" severity note;
    report "LAB06_GAME_TB: ALL CHECKS PASS" severity note;
    game_done <= '1';
    wait;
  end process;
end architecture;