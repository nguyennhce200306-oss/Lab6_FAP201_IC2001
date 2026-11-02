library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
entity key_conditioner_tb is end;
architecture test of key_conditioner_tb is
 signal clk : std_logic := '0';
 signal rst : std_logic := '0';
 signal raw : std_logic := '0';
 signal pulse, stable : std_logic;
 signal pulses_seen : integer := 0;
begin
 clk <= not clk after 10 ns;
 dut: entity work.key_conditioner(rtl)
  generic map(G_STABLE_CYCLES => 3)
  port map(clk_i => clk, rst_i => rst, raw_pressed_i => raw,
           press_pulse_o => pulse, stable_pressed_o => stable);
 process(clk)
 begin
  if rising_edge(clk) then
   if pulse = '1' then pulses_seen <= pulses_seen + 1; end if;
  end if;
 end process;
 test: process
  procedure tick is
  begin wait until rising_edge(clk); wait for 1 ns; end;
 begin
  rst <= '1'; tick; tick; rst <= '0'; tick;
  -- bounce too short to count
  raw <= '1'; tick; raw <= '0'; tick;
  raw <= '1'; tick; raw <= '0'; tick;
  for i in 1 to 5 loop tick; end loop;
  assert stable = '0' and pulses_seen = 0
   report "Short bounce was incorrectly accepted" severity failure;
  -- long stable press => one event
  raw <= '1';
  for i in 1 to 10 loop tick; end loop;
  assert stable = '1' and pulses_seen = 1
   report "Long press should produce one pulse" severity failure;
  for i in 1 to 8 loop tick; end loop;
  assert pulses_seen = 1 report "Holding a key repeated event" severity failure;
  raw <= '0';
  for i in 1 to 10 loop tick; end loop;
  assert stable = '0' and pulses_seen = 1
   report "Release unexpectedly produced another press event" severity failure;
  report "KEY_CONDITIONER_TB: ALL CHECKS PASS" severity note;
  stop;
  wait;
 end process;
end architecture;