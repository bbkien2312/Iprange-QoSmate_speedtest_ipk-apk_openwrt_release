# OpenWrt QoSmate IP Limit + Speed Test

Ứng dụng LuCI mở rộng cho QoSmate, phục vụ giới hạn tốc độ theo IP/dải IP và
đo tốc độ mạng trực tiếp từ router.

## Tính năng

- IP đơn: `192.168.1.45`
- Dải IP: `192.168.1.10-192.168.1.60`
- `per_ip`: mỗi IP có một bucket giới hạn riêng
- `shared_range`: cả dải IP dùng chung một bucket
- Download/upload độc lập
- Chế độ `Per-IP` hoặc `Shared range`
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

## Cấu hình Rate Limits trên LuCI

Vào `Network → QoSmate → Rate Limits`, tạo rule mới:

1. Nhập IP, CIDR hoặc dải IPv4 ở `Target Devices`.
2. Chọn `Per-IP` để mỗi địa chỉ có một bucket riêng, hoặc `Shared range` để
   toàn bộ target dùng chung một bucket.
3. Nhập giá trị Download/Upload và chọn đơn vị tương ứng.
4. Bật rule rồi Save & Apply.

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

Đẩy hai package trong `dist-standard/` lên repository GitHub public rồi thay
`OWNER/REPO` bằng repository thật trong lệnh dưới đây:

```powershell
git init
git add AGENTS.md README.md docs tools vendor dist dist-standard
git commit -m "QoSmate fork with speedtestcpp and health actions"
git branch -M main
git remote add origin https://github.com/OWNER/REPO.git
git push -u origin main
```

```sh
wget -qO- https://raw.githubusercontent.com/OWNER/REPO/main/tools/install_from_git.sh | sh
```

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
| Đơn vị MB/s, Mbps, KB/s, Kbps | Thường nhập kbit/s | Có chuyển đổi tự động |
| Speed test trên router | Không có trong bản gốc đang dùng | Có speedtestcpp và LibreSpeed fallback |
| Server Việt Nam/quốc tế | Không có | Có dropdown và Automatic |
| Nút setup speedtestcpp | Không có | Có; `OK` thì tự ẩn |
| Health action | Kiểm tra cơ bản | Có nút sửa Service/Nft/Tc/Config/Packages/integrity |
| Statistics khi không có qdisc | Có thể blank/lỗi | Trả `status=disabled` và hướng dẫn |
| Updater upstream | Có thể cập nhật bản gốc | Tắt để bảo vệ phần fork |
| Đóng gói | Theo upstream/feed | Có `.ipk` chuẩn và `.apk` thử nghiệm |