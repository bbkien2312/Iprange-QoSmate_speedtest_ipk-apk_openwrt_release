# QoSmate IP Limit + Speed Test — Hướng dẫn sử dụng

Bản fork LuCI cho OpenWrt, dùng để giới hạn download/upload theo IP hoặc dải
IPv4 và chạy speed test trực tiếp từ WAN của router.

## Cài đặt hoặc cập nhật

Áp dụng cho OpenWrt 24.x (`opkg`) và 25.x (`apk`). Đăng nhập SSH vào router rồi
chạy:

```sh
wget -qO- https://raw.githubusercontent.com/bbkien2312/Iprange-QoSmate_speedtest_ipk-apk_openwrt_release/main/install_from_git.sh | sh
```

Để cập nhật bản mới mà giữ cấu hình và không tự bật shaping:

```sh
QOSMATE_ENABLE=0 sh -c "$(wget -qO- https://raw.githubusercontent.com/bbkien2312/Iprange-QoSmate_speedtest_ipk-apk_openwrt_release/main/install_from_git.sh)"
```

Sau khi cài, mở `Network → QoSmate`. Nếu giao diện cũ còn cache, nhấn
`Ctrl+F5` hoặc đăng xuất/đăng nhập lại LuCI.

Ứng dụng không flash firmware và không sửa bootloader. Tuy nhiên, shaping có
thể làm giảm tốc độ hoặc gián đoạn Internet trong lúc áp dụng; nên giữ SSH LAN
để rollback.

## Basic Settings

Trong `Network → QoSmate → Settings`:

1. Chọn đúng WAN interface, thường là `wan`.
2. Nhập Download/Upload Rate theo `kbps`.
3. Đặt cả hai rate bằng `0` để tắt shaping tổng; trạng thái `Tc:off` và WAN
   `noqueue` trong trường hợp này là bình thường.
4. Chọn Root Qdisc. Dùng `CAKE` khi cần `Shared range - Fair Share`.
5. Bấm `Save & Apply`.

Rate Basic Settings là trần shaping của toàn WAN, không làm đường truyền ISP
nhanh hơn. Muốn router chạy không giới hạn, đặt `0/0` và tắt các rule Rate
Limits đang bật.

## Rate Limits

Mở `Network → QoSmate → Rate Limits`, chọn `Add` và nhập:

- `Target Devices`: một IP (`192.168.1.45`), CIDR hoặc dải liên tục như
  `192.168.1.10-192.168.1.60`.
- `Limit mode`: `Per-IP`, `Shared range` hoặc `Shared range - Fair Share`.
- Download/Upload value và đơn vị `MB/s`, `Mbps`, `KB/s` hoặc `Kbps`.
- Bật `Enabled`, sau đó `Save & Apply`.

Ý nghĩa các chế độ:

- `Per-IP`: mỗi IP có một bucket riêng. Ví dụ 5 MB/s nghĩa là mỗi IP có thể
  dùng tối đa khoảng 5 MB/s.
- `Shared range`: cả dải IP dùng chung một tổng bucket. Một thiết bị có thể
  chiếm phần lớn tổng băng thông.
- `Shared range - Fair Share`: dùng CAKE host isolation để các IP đang truyền
  chia đều bucket; host không truyền không giữ băng thông. Nếu một IP dùng ít,
  phần còn lại được IP khác sử dụng.

### Điều kiện Fair Share

Trong `Settings`, chọn `Root Qdisc = CAKE`; trong tab `CAKE`, bật `Host
Isolation`. Fair Share hiện phân loại trực tiếp IPv4 cụ thể. IPv6, IP set động
hoặc nhiều rule Fair Share có thể dùng nftables fallback và hiển thị cảnh báo.

### View Clients / View details

Ở mỗi rule, cột Target được rút gọn thành IP hoặc range. Bấm `View Clients` để
xem từng IP:

- hostname/MAC nếu DHCP hoặc neighbor table biết;
- trạng thái `Active`, `Online/idle` hoặc `Unused`;
- số connection;
- tốc độ Download/Upload mẫu, cập nhật khoảng 3 giây.

Thiết bị phía sau router NAT phụ chỉ xuất hiện dưới IP của router phụ. Nếu
conntrack không khả dụng, IP vẫn hiện nhưng live rate có thể là `—`.

### Burst Factor

`0` là giới hạn nghiêm ngặt. `1.0` cho phép burst ngắn ban đầu khoảng một giây;
giá trị lớn hơn cho burst lớn hơn, không tăng tổng quota Fair Share.

## Statistics và Service Status

Tab `Statistics` hiển thị counter khi qdisc đang hoạt động. Nếu Download và
Upload đều bằng `0`, trạng thái `disabled/no_qdisc` là bình thường, không phải
lỗi.

Trong Settings, nút Repair/Apply chỉ xuất hiện khi Service, Nft, Tc, Config,
Packages hoặc integrity có trạng thái cảnh báo/lỗi. Thành phần đã `OK` sẽ ẩn
nút tương ứng.

## Speed Test

Mở `Network → QoSmate → Speed Test`.

1. Nếu `SpeedTest++` là `NOT YET`, bấm `Setup speedtestcpp`; khi cài xong nút
   tự ẩn và trạng thái thành `OK`.
2. Chọn `Automatic (best server for WAN IP)` để SpeedTest++ tự chọn server gần
   và phù hợp nhất với WAN.
3. Hoặc chọn host cố định theo nhóm Việt Nam, Singapore, Nhật, Úc, Trung Quốc,
   Hong Kong, Đài Loan, Thái Lan, Philippines, Indonesia, Ấn Độ, Trung Á, Nga,
   châu Âu, Mỹ và châu Phi.
4. Có thể chọn `Custom Ookla host:port` nếu có endpoint riêng.
5. Bấm `Start speed test`.

Kết quả hiển thị:

- Download/Upload theo Mbps và MB/s;
- Ping và Jitter theo ms;
- engine `speedtestcpp` và host đã dùng.

Một số server trả `ping=0` trong JSON. Ứng dụng sẽ tự ping ICMP trung bình 3
lần để hiển thị RTT; nếu server chặn ICMP thì hiển thị `?`. Host cố định có thể
thay đổi hoặc tạm ngừng, nên chuyển về `Automatic` nếu test lỗi.

Speed test chạy từ chính router qua WAN, không đo riêng một client LAN và không
phản ánh trực tiếp giới hạn của một IP trong Rate Limits.

## Nhận biết phiên bản

`Network → QoSmate → Settings` hiển thị banner `QoSmate fork build`, phiên bản,
commit Git ngắn và thời điểm build. Sau cập nhật, nếu chưa thấy thay đổi hãy
refresh lại LuCI.

## Tắt hoặc gỡ ứng dụng

Tắt tạm mà không gỡ:

```sh
/etc/init.d/qosmate stop
/etc/init.d/qosmate disable
```

Gỡ package trên OpenWrt 24.x:

```sh
opkg remove luci-app-qosmate qosmate
```

Trên OpenWrt 25.x:

```sh
apk del luci-app-qosmate qosmate
```

File cấu hình `/etc/config/qosmate` có thể được giữ lại để khôi phục sau này.
