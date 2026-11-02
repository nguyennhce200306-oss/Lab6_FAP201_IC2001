# Lab6_FAP201 - Memory Game (Simon Says) with 7-Segment Display (74HC595)

## Thông tin chung
* **Môn học:** FAP201 - FPGA Programming
* **Bài thực hành:** Lab06 - Memory Game (FSM)
* **Mục tiêu:** 
  * Thiết kế trò chơi trí nhớ (dựa trên game Simon Says) điều khiển bằng máy trạng thái (FSM).
  * Ứng dụng thanh ghi dịch phản hồi tuyến tính (LFSR) để tạo số ngẫu nhiên (chọn chuỗi LED phát sáng)[cite: 32].
  * Giao tiếp với IC ghi dịch 74HC595 để hiển thị điểm số và trạng thái (Win/Lose) lên màn hình LED 7 đoạn (7-Segment)[cite: 32].

## Môi trường và Phần cứng
* **Công cụ phát triển:** Gowin EDA
* **Bo mạch (Board):** Xiaomeige ACG525[cite: 30]
* **Chip FPGA (Target Device):** GW5A-LV25UG324C2/I1[cite: 30]
* **Xung nhịp hệ thống (Clock):** 50 MHz (Chu kỳ 20 ns)[cite: 31]
* **IC Mở rộng:** 74HC595 (Điều khiển LED 7 đoạn)[cite: 30, 32]
* **Ngôn ngữ:** VHDL (IEEE 1164 STD_LOGIC)[cite: 32]

---

## Kiến trúc Thiết kế (System Architecture)
Hệ thống bao gồm 4 module chính được liên kết trong entity top `lab06_top_74hc595`[cite: 32]:

### 1. Module `key_conditioner` (Mạch khử rung & Bắt cạnh)
* Thực hiện đồng bộ hóa (2 Flip-Flop) và khử rung phím (Debounce) trong $20\text{ ms}$ (định mức đếm `1.000.000` chu kỳ ở $50\text{ MHz}$)[cite: 32].
* Module bắt cạnh nhấn phím và chỉ tạo ra duy nhất một xung clock (`press_pulse_o = '1'`) tương ứng với mỗi lần người dùng thao tác bấm thành công[cite: 32].

### 2. Module `lab06_game` (Khối FSM & LFSR xử lý luật chơi)
* Trò chơi bao gồm 6 trạng thái chính (`IDLE`, `PATTERN_OFF`, `PATTERN_SHOW`, `WAIT_PLAYER`, `WIN`, `LOSE`)[cite: 32].
* **Quá trình chơi:** Mạch sẽ hiển thị chuỗi LED phát sáng với độ dài tăng dần qua mỗi vòng (tối đa 7 vòng). Người chơi phải bấm các nút (`press_i`) sao cho khớp với thứ tự mạch đã sáng[cite: 32].
* Thời gian chớp tắt được điều chỉnh qua bộ định thời (`G_OFF_TICKS` là $0.3\text{ s}$ và `G_SHOW_TICKS` là $0.4\text{ s}$)[cite: 32].
* LFSR độ rộng 8-bit được sử dụng để giả lập chuỗi giả ngẫu nhiên (PRNG), tạo tính ngẫu nhiên mỗi khi trò chơi bắt đầu[cite: 32].

### 3. Module `sevenseg_74hc595` (Giao tiếp SPI/Shift Register tới LED 7 đoạn)
* Để hiển thị dữ liệu lên cụm LED 7 đoạn, mạch giao tiếp với hai chip 74HC595 mắc nối tiếp, yêu cầu đẩy $16\text{ bits}$ tuần tự ra (8 bit chọn mã hiển thị LED và 8 bit chọn digit)[cite: 32].
* Hệ thống tạo ra một FSM truyền thông với các trạng thái (`LOAD`, `SH_HIGH`, `SH_LOW`, `LATCH_HIGH`, `LATCH_LOW`, `REFRESH`) để đẩy dữ liệu nối tiếp qua ngõ `ds_o` dựa vào xung nhịp dịch `shcp_o` và xung nhịp chốt `stcp_o`[cite: 32].
* Bảng hiển thị: Số `1-7` (hiển thị level hiện tại), chữ `F` (Lose - Thất bại) và chữ `A` (Win - Hoàn thành)[cite: 32].

### 4. Module Top `lab06_top_74hc595`
* Đảm nhận kết nối các nút nhấn (cấu hình Active-Low) vào khối game và kết nối kết quả điều khiển ra mạch 74HC595 và dàn đèn LED hiển thị trên mạch[cite: 32].
* Khối phát hiện trạng thái khởi động tự động sinh ra một xung mồi `powerup_start` để kích hoạt game chạy ngay lần đầu nạp mạch[cite: 32]. Chơi lại game bằng phím `KEY0` khi đang ở trạng thái Win/Lose[cite: 32].

---

## Cấu hình Chân & Ràng buộc Thời gian (Constraints)

### 1. Ánh xạ chân vật lý (`Lab6.cst`)
Tín hiệu được cấu hình trong file `.cst` với chuẩn I/O `LVCMOS33`[cite: 30]:

| Tín hiệu VHDL | Chân FPGA | Kéo trở (Pull) | Mô tả |
| :--- | :---: | :--- | :--- |
| `clk_50m_i` | `T9` | `NONE` | Xung nhịp hệ thống 50MHz[cite: 30] |
| `key_raw_i[0]` | `B16` | `UP` | Nút nhấn chơi game 1 (và nút Replay)[cite: 30, 32] |
| `key_raw_i[1]` | `A15` | `UP` | Nút nhấn chơi game 2[cite: 30] |
| `key_raw_i[2]` | `C15` | `UP` | Nút nhấn chơi game 3[cite: 30] |
| `led_pin_o[0]` | `D14` | `NONE` | LED nháy tín hiệu 1[cite: 30] |
| `led_pin_o[1]` | `C14` | `NONE` | LED nháy tín hiệu 2[cite: 30] |
| `led_pin_o[2]` | `B9` | `NONE` | LED nháy tín hiệu 3[cite: 30] |
| `seg_ds_o` | `F4` | `NONE` | Dữ liệu nối tiếp (Serial Data) giao tiếp 74HC595[cite: 30, 32] |
| `seg_stcp_o` | `F3` | `NONE` | Xung chốt hiển thị (Latch/Storage Clock)[cite: 30, 32] |
| `seg_shcp_o` | `H4` | `NONE` | Xung dịch dữ liệu (Shift Clock)[cite: 30, 32] |

### 2. Ràng buộc thời gian (`Lab6.sdc`)
File `.sdc` định nghĩa xung nhịp vào chân `clk_50m_i` tần số 50 MHz (Chu kỳ 20 ns)[cite: 31]:
```tcl
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk_50m_i}]
```[cite: 31]

---

## Hướng dẫn Build & Kiểm chứng (Execution & Verification)

1. **Tổng hợp & Phân tích định thì (Synthesis & STA):**
   * Mở project trong Gowin EDA, nạp file top `Lab6.vhd`, file `Lab6.cst` và `Lab6.sdc`[cite: 30, 31, 32].
   * Thực hiện **Synthesis** và **Place & Route**. 
   * Đọc báo cáo Timing để đảm bảo xung nhịp $50\text{ MHz}$ đáp ứng đủ Setup/Hold Time và đảm bảo phần trăm sử dụng khối Logic LUT/Register phù hợp[cite: 31, 32].

2. **Nạp phần cứng (Hardware):**
   * Sử dụng Gowin Programmer nạp file bitstream (`.fs`) xuống mạch Xiaomeige ACG525[cite: 30].
   * Quan sát cụm LED 3 đèn sẽ sáng lần lượt để báo chuỗi ngẫu nhiên[cite: 32].
   * Đèn LED 7 đoạn hiển thị số vòng (từ 1 đến 7)[cite: 32]. Bấm các phím `B16, A15, C15` tương ứng để nhắc lại chuỗi[cite: 30, 32]. 
   * Trạng thái Thua hiện chữ `F`, trạng thái Thắng hiện chữ `A`[cite: 32]. Nhấn nút `B16` để làm lại từ đầu[cite: 30, 32].
