-- DỮ LIỆU MẪU BỔ SUNG
USE QuanLyVeMayBay;
GO

-- Thêm dữ liệu mẫu cho các bảng
INSERT INTO KhachHang (HoTen, GioiTinh, NgaySinh, SoDienThoai, Email, CCCD) VALUES
(N'Nguyễn Văn An', N'Nam', '1990-01-15', '0912345678', 'nguyenvana@email.com', '001123456789'),
(N'Trần Thị Bình', N'Nữ', '1985-05-20', '0923456789', 'tranthib@email.com', '001123456790'),
(N'Lê Văn Cường', N'Nam', '1992-08-30', '0934567890', 'levanc@email.com', '001123456791');

-- Thêm chuyến bay mẫu
EXEC sp_ThemChuyenBay 
    @MaChuyenBay = 'CB0001',
    @MaMayBay = 'MB001',
    @SanBayDi = 'SBN01',
    @SanBayDen = 'SGN01',
    @NgayGioDi = '2024-12-01 07:00:00',
    @NgayGioDen = '2024-12-01 09:30:00',
    @GiaVeCoBan = 1200000.00;

-- Tạo admin mẫu
EXEC sp_CreateAdminSample;
