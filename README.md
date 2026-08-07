# OpenWrt QoSmate IP Limit + Speed Test

Ứng dụng LuCI mở rộng cho QoSmate, phục vụ giới hạn tốc độ theo IP/dải IP và
đo tốc độ mạng trực tiếp từ router.

## Tính năng

- IP đơn: `192.168.1.45`
- Dải IP: `192.168.1.10-192.168.1.60`
- `per_ip`: mỗi IP có một bucket giới hạn riêng
- `shared_range`: cả dải IP dùng chung một bucket
- Download/upload độc lập
- Chế độ `Per-IP`, `Shared range` hoặc `Shared range - Fair Share`
- Nhập dải IPv4 dạng `192.168.1.10-192.168.1.60`
- Đơn vị giới hạn `MB/s`, `Mbps`, `KB/s`, `Kbps`
- Giao diện LuCI: `Network → QoSmate → Speed Test`
- Speed test bằng `speedtestpp` hoặc `librespeed-cli`
- Kết quả ping, jitter, download, upload và trạng thái RPC
- OpenWrt 24.x (`opkg`/`.ipk`) và 25.x (`apk`/`.apk`)

## Kiến trúc source

```text
vendor/qosmate/              backend QoSmate fork
vendor/luci-app-qosmate/     LuCI fork và trang Speed Test
tools/bootstrap.ps1          tạo .venv
tools/build_sdk_packages.ps1 build .ipk bằng SDK
tools/build_packages.py      build artifact thử nghiệm
docs/                        kiến trúc, test, changelog
dist-standard/               package chuẩn từ ipkg-build
.venv/                       công cụ Python, không commit
```

## Chuẩn bị môi trường

```powershell
.\tools\bootstrap.ps1
.\.venv\Scripts\Activate.ps1
```

SDK OpenWrt phải đúng target/version. Không dùng package của target khác.

## Build OpenWrt 24.x

### Cách đọc môi trường chạy lệnh

- Lệnh có nhãn `MÁY TÍNH - PowerShell/CMD` chạy trên máy Windows chứa source.
- Lệnh có nhãn `ROUTER - SSH` chạy sau khi đăng nhập vào OpenWrt.
- Không có ký hiệu `IR` bắt buộc phải dùng công cụ riêng; `PS`/`CMD` chỉ là
  PowerShell/Command Prompt để build, còn `sh` là shell trên router để cài.

```powershell
.\tools\build_sdk_packages.ps1
```

Kết quả trong `dist-standard/`:

- `qosmate_*_all.ipk`
- `luci-app-qosmate_*_all.ipk`

Trên router 24.x:

```sh
opkg update
opkg install tc-full ip-full kmod-ifb kmod-sched-cake \
  kmod-sched-ctinfo kmod-sched-red kmod-veth librespeed-cli
opkg install /tmp/qosmate_*.ipk /tmp/luci-app-qosmate_*.ipk
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

## Build OpenWrt 25.x

Dùng SDK/Buildroot 25.x tương ứng để tạo `.apk`; không đổi đuôi `.ipk` thủ
công. Cài package bằng `apk`, sau đó kiểm tra dependency và chữ ký package.

## Kiểm thử an toàn

Trước khi cài trên router:

1. Kiểm tra phiên bản, kiến trúc và kernel.
2. Backup `/etc/config` và danh sách package.
3. Chỉ cài dependency đúng kernel.
4. Kiểm tra LuCI/RPC/speed test trước khi bật shaping.
5. Chưa enable QoSmate hoặc áp dụng rule giới hạn nếu chưa có kết quả test.

Xem [docs/testing.md](docs/testing.md) và [docs/changelog.md](docs/changelog.md).

`shared_fair`: dải IP dùng chung, được đưa vào CAKE child queue riêng và host-isolation chia đều.

## Cấu hình Rate Limits trên LuCI

Vào `Network → QoSmate → Rate Limits`, tạo rule mới:

1. Nhập IP, CIDR hoặc dải IPv4 ở `Target Devices`.
2. Chọn `Per-IP` để mỗi địa chỉ có một bucket riêng, `Shared range` để toàn bộ
   target dùng chung một bucket, hoặc `Shared range - Fair Share` để CAKE chia
   lại cho các IP đang truyền. Fair Share không có Newcomer Reserve 10%.
3. Nhập giá trị Download/Upload và chọn đơn vị tương ứng.
4. Bật rule rồi Save & Apply.

Với Fair Share, vào `Basic Settings`, chọn `Root Qdisc = cake` và trong tab
`CAKE` giữ `Host Isolation = enabled`. Backend tạo parent HTB theo Basic rate,
child CAKE riêng cho dải và class mặc định cho IP ngoài dải. IPv4 cụ thể được
phân loại trực tiếp; IPv6, IP set động hoặc nhiều Fair Share rule dùng nft fallback.

### Lịch sử triển khai Fair Share (2026-08-07)

- Đã build `.ipk` cho OpenWrt 24.x và `.apk` cho OpenWrt 25.x; APK cũng chứa
  trang Rate Limits để hiển thị lựa chọn Fair Share.
- Đã cài thử trên `10.5.0.1:22191`; backend tạo child target-only và class mặc định
  cho IP ngoài dải. Test `0/0` trả `tc:off`, sau đó cấu hình Fair Share được khôi phục.
- Speedtest router đạt `316.90 Mbps` và đi vào class mặc định; cần client thật trong
  dải 10–59 để đo giới hạn 10 MB/s và chia đều giữa nhiều IP.

Ví dụ `5 MB/s` tương đương `40 Mbps` hoặc `40000 Kbps`.

## Speed Test trên LuCI

Vào `Network → QoSmate → Speed Test`, chọn `Automatic` hoặc một server trong
dropdown (Singapore, Tokyo, Prague, Frankfurt, New York, Los Angeles), rồi bấm
`Start speed test`. Có thể chọn `Custom server ID` để nhập ID khác. Trạng thái
được cập nhật tự động. Kết quả là tốc độ của router qua WAN; nó không đại diện
riêng cho một client LAN.

## Phần bổ sung của bản fork

Bản fork giữ nguyên engine shaping của QoSmate gốc và bổ sung:

- Nút health cho Service, Nft, Tc, Config, Packages và integrity. Nút chỉ hiện
  khi kiểm tra trả `!`/`x`; khi `OK` thì tự ẩn. Package sửa lỗi được lấy từ
  `/tmp/qosmate-fork`, không gọi updater upstream.
- `Tc:off` và "Shaping disabled" là thông tin khi hai rate Basic Settings bằng
  `0`, không phải lỗi.
- Statistics trả trạng thái disabled rõ ràng khi không có qdisc. Muốn có counter
  queue phải đặt Download/Upload Rate lớn hơn 0 rồi Save & Apply.
- Speed Test dùng `speedtestcpp` (binary `speedtest`) nếu có; nút Setup tự ẩn
  sau khi trạng thái chuyển thành `OK`.

### Cài một dòng SSH từ Git

Repository release public:

`https://github.com/bbkien2312/Iprange-QoSmate_speedtest_ipk-apk_openwrt_release`

```sh
wget -qO- https://raw.githubusercontent.com/bbkien2312/Iprange-QoSmate_speedtest_ipk-apk_openwrt_release/main/install_from_git.sh | sh
```

Để cập nhật fork đang có lên phiên bản mới nhất, giữ cấu hình và không bật
shaping:

```sh
QOSMATE_ENABLE=0 sh -c "$(wget -qO- https://raw.githubusercontent.com/bbkien2312/Iprange-QoSmate_speedtest_ipk-apk_openwrt_release/main/install_from_git.sh)"
```

Chỉ dùng `QOSMATE_ENABLE=1` nếu muốn cập nhật xong rồi restart service và áp dụng
shaping hiện tại.

Installer tự nhận `opkg` (OpenWrt 24.x) hoặc `apk` (OpenWrt 25.x), tải package
vào `/tmp/qosmate-fork`, cài đặt rồi restart `rpcd`/`uhttpd`. Script không ghi
đè UCI và không tự bật shaping. Muốn bật service, đặt `QOSMATE_ENABLE=1`.
Với `apk`, script dùng artifact trong `dist/` từ `python tools/build_packages.py`;
với `opkg`, dùng package SDK trong `dist-standard/`.

Repository private không dùng được raw URL không xác thực. Dùng GitHub Release
hoặc server nội bộ nếu cần private. Không đưa mật khẩu router/token vào Git.
Ghi chú build/test nằm trong `AGENTS.md` và `docs/changelog.md`.

Ứng dụng không flash firmware và không ghi bootloader. Tuy vậy, rule nftables/tc
sai có thể làm mất Internet tạm thời. Luôn giữ SSH LAN để rollback và không mở
## Safety warning

router root không mật khẩu ra WAN.

## So sánh QoSmate gốc và bản fork

| Hạng mục | QoSmate gốc | Bản fork này |
|---|---|---|
| HFSC/CAKE/HTB, IFB, nftables, DSCP | Có | Giữ nguyên |
| Shaping tổng theo WAN | Có | Giữ nguyên |
| Một IP | Có tính năng cơ bản | Có Per-IP rõ ràng |
| Dải `192.168.1.10-192.168.1.60` | Không có sẵn | Có mở rộng dải IPv4 |
| Dải dùng chung một tổng tốc độ | Không có sẵn | Có Shared range |
| Fair Share theo host đang hoạt động | Không có UI riêng | Có `shared_fair` dựa trên CAKE host isolation |
| Đơn vị MB/s, Mbps, KB/s, Kbps | Thường nhập kbit/s | Có chuyển đổi tự động |
| Speed test trên router | Không có trong bản gốc đang dùng | Có speedtestcpp và LibreSpeed fallback |
| Server Việt Nam/quốc tế | Không có | Có dropdown và Automatic |
| Nút setup speedtestcpp | Không có | Có; `OK` thì tự ẩn |
| Health action | Kiểm tra cơ bản | Có nút sửa Service/Nft/Tc/Config/Packages/integrity |
| Statistics khi không có qdisc | Có thể blank/lỗi | Trả `status=disabled` và hướng dẫn |
| Updater upstream | Có thể cập nhật bản gốc | Tắt để bảo vệ phần fork |
| Đóng gói | Theo upstream/feed | Có `.ipk` chuẩn và `.apk` thử nghiệm |

### Lưu ý hiệu năng CAKE trên MT7621

`Basic Settings` chỉ là trần shaping. Trên Xiaomi Mi Router 3G, CAKE ở mức trần
cao vẫn xử lý toàn bộ lưu lượng WAN/IFB và có thể làm giảm download. Nếu cần full
speed, stop/disable QoSmate; không dùng `800000`/`2000000` với mục đích “tăng tốc”.
