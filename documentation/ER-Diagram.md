# 🗃️ SƠ ĐỒ DATABASE - HỆ THỐNG ĐẶT VÉ MÁY BAY

## 📋 TỔNG QUAN DATABASE
Hệ thống quản lý đặt vé máy bay với đầy đủ tính năng: quản lý khách hàng, chuyến bay, đặt vé, thanh toán và phân quyền.

## 🗂 DANH SÁCH BẢNG

### 👥 **KhachHang** - Quản lý thông tin khách hàng
| Column | Type | Mô tả |
|--------|------|-------|
| MaKH | INT IDENTITY(1,1) PRIMARY KEY | Mã khách hàng |
| HoTen | NVARCHAR(100) NOT NULL | Họ tên |
| GioiTinh | NVARCHAR(10) | Giới tính |
| NgaySinh | DATE | Ngày sinh |
| SoDienThoai | VARCHAR(15) | Số điện thoại |
| Email | NVARCHAR(100) | Email |
| CCCD | VARCHAR(20) UNIQUE | CCCD/CMND |

### 🛫 **ChuyenBay** - Quản lý chuyến bay
| Column | Type | Mô tả |
|--------|------|-------|
| MaChuyenBay | CHAR(6) PRIMARY KEY | Mã chuyến bay |
| MaMayBay | CHAR(5) NOT NULL | Mã máy bay |
| SanBayDi | CHAR(5) NOT NULL | Sân bay đi |
| SanBayDen | CHAR(5) NOT NULL | Sân bay đến |
| NgayGioDi | DATETIME NOT NULL | Ngày giờ đi |
| NgayGioDen | DATETIME NOT NULL | Ngày giờ đến |
| GiaVeCoBan | DECIMAL(12,2) NOT NULL | Giá vé cơ bản |

### 🎫 **Ve** - Quản lý vé
| Column | Type | Mô tả |
|--------|------|-------|
| MaVe | INT IDENTITY(1,1) PRIMARY KEY | Mã vé |
| MaChuyenBay | CHAR(6) NOT NULL | Mã chuyến bay |
| HangVe | NVARCHAR(20) DEFAULT N'Economy' | Hạng vé |
| GiaVe | DECIMAL(12,2) NOT NULL | Giá vé |
| TrangThai | NVARCHAR(20) DEFAULT N'Chưa bán' | Trạng thái vé |
| SoCho | INT | Số chỗ |

### 💳 **DatVe** - Lịch sử đặt vé
| Column | Type | Mô tả |
|--------|------|-------|
| MaDatVe | INT IDENTITY(1,1) PRIMARY KEY | Mã đặt vé |
| MaKH | INT NOT NULL | Mã khách hàng |
| MaVe | INT NOT NULL | Mã vé |
| NgayDat | DATETIME DEFAULT GETDATE() | Ngày đặt |
| TongTien | DECIMAL(12,2) NOT NULL | Tổng tiền |

### 🔐 **Users** - Quản lý người dùng hệ thống
| Column | Type | Mô tả |
|--------|------|-------|
| UserID | INT IDENTITY PRIMARY KEY | ID người dùng |
| Username | VARCHAR(50) UNIQUE NOT NULL | Tên đăng nhập |
| PasswordHash | VARBINARY(32) NOT NULL | Mật khẩu hash |
| FullName | NVARCHAR(100) | Họ tên |
| CreatedAt | DATETIME DEFAULT GETDATE() | Ngày tạo |
| IsLocked | BIT DEFAULT 0 | Trạng thái khóa |

## 🔗 QUAN HỆ (RELATIONSHIPS)

```mermaid
graph TB
    A[KhachHang] -->|1-n| B[DatVe]
    B -->|n-1| C[Ve]
    C -->|n-1| D[ChuyenBay]
    D -->|n-1| E[MayBay]
    D -->|n-1| F[SanBay - Đi]
    D -->|n-1| G[SanBay - Đến]
    H[Users] -->|n-n| I[Roles]
