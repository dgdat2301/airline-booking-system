-- ===================================================
-- HỆ THỐNG QUẢN LÝ ĐẶT VÉ MÁY BAY - TOÀN BỘ TRONG 1 FILE
-- Chạy trên SQL Server (SSMS)
-- ===================================================

-- 1. TẠO / CHẠY DATABASE
USE master;
GO

IF EXISTS(SELECT 1 FROM sys.databases WHERE name = 'QuanLyVeMayBay')
BEGIN
    ALTER DATABASE QuanLyVeMayBay SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QuanLyVeMayBay;
END
GO

CREATE DATABASE QuanLyVeMayBay;
GO

USE QuanLyVeMayBay;
GO

SET NOCOUNT ON;
GO

-- =============================================
-- 2. TẠO BẢNG CHÍNH
-- =============================================

-- Bảng KhachHang
CREATE TABLE KhachHang (
    MaKH INT IDENTITY(1,1) PRIMARY KEY,
    HoTen NVARCHAR(100) NOT NULL,
    GioiTinh NVARCHAR(10) NULL,
    NgaySinh DATE NULL,
    SoDienThoai VARCHAR(15) NULL,
    Email NVARCHAR(100) NULL,
    CCCD VARCHAR(20) NULL UNIQUE
);
GO

-- Bảng SanBay
CREATE TABLE SanBay (
    MaSanBay CHAR(5) PRIMARY KEY,
    TenSanBay NVARCHAR(100) NOT NULL,
    ThanhPho NVARCHAR(50) NULL
);
GO

-- Bảng MayBay
CREATE TABLE MayBay (
    MaMayBay CHAR(5) PRIMARY KEY,
    HangMayBay NVARCHAR(50) NULL,
    TongSoGhe INT NOT NULL CHECK (TongSoGhe > 0)
);
GO

-- Bảng ChuyenBay
CREATE TABLE ChuyenBay (
    MaChuyenBay CHAR(6) PRIMARY KEY,
    MaMayBay CHAR(5) NOT NULL,
    SanBayDi CHAR(5) NOT NULL,
    SanBayDen CHAR(5) NOT NULL,
    NgayGioDi DATETIME NOT NULL,
    NgayGioDen DATETIME NOT NULL,
    GiaVeCoBan DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_ChuyenBay_MayBay FOREIGN KEY (MaMayBay) REFERENCES MayBay(MaMayBay),
    CONSTRAINT FK_ChuyenBay_SanBayDi FOREIGN KEY (SanBayDi) REFERENCES SanBay(MaSanBay),
    CONSTRAINT FK_ChuyenBay_SanBayDen FOREIGN KEY (SanBayDen) REFERENCES SanBay(MaSanBay),
    CONSTRAINT CHK_ChuyenBay_Time CHECK (NgayGioDen > NgayGioDi)
);
GO

-- Bảng Ve
CREATE TABLE Ve (
    MaVe INT IDENTITY(1,1) PRIMARY KEY,
    MaChuyenBay CHAR(6) NOT NULL,
    HangVe NVARCHAR(20) NOT NULL DEFAULT N'Economy',
    GiaVe DECIMAL(12,2) NOT NULL,
    TrangThai NVARCHAR(20) NOT NULL DEFAULT N'Chưa bán',
    SoCho INT NULL,
    CONSTRAINT FK_Ve_ChuyenBay FOREIGN KEY (MaChuyenBay) REFERENCES ChuyenBay(MaChuyenBay)
);
GO

-- Bảng DatVe
CREATE TABLE DatVe (
    MaDatVe INT IDENTITY(1,1) PRIMARY KEY,
    MaKH INT NOT NULL,
    MaVe INT NOT NULL,
    NgayDat DATETIME NOT NULL DEFAULT GETDATE(),
    TongTien DECIMAL(12,2) NOT NULL,
    CONSTRAINT FK_DatVe_KhachHang FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH),
    CONSTRAINT FK_DatVe_Ve FOREIGN KEY (MaVe) REFERENCES Ve(MaVe)
);
GO

-- =============================================
-- 3. BẢNG QUẢN LÝ NGƯỜI DÙNG / ROLES / LOG / ATTEMPTS
-- =============================================

-- Users: lưu password hash (SHA2_256)
CREATE TABLE Users (
    UserID INT IDENTITY PRIMARY KEY,
    Username VARCHAR(50) UNIQUE NOT NULL,
    PasswordHash VARBINARY(32) NOT NULL, -- HASHBYTES('SHA2_256', password)
    FullName NVARCHAR(100),
    CreatedAt DATETIME DEFAULT GETDATE(),
    IsLocked BIT DEFAULT 0
);
GO

-- Roles
CREATE TABLE Roles (
    RoleID INT IDENTITY PRIMARY KEY,
    RoleName VARCHAR(50) UNIQUE NOT NULL,
    Description NVARCHAR(200)
);
GO

-- UserRoles (N-N)
CREATE TABLE UserRoles (
    UserID INT NOT NULL,
    RoleID INT NOT NULL,
    AssignedAt DATETIME DEFAULT GETDATE(),
    PRIMARY KEY (UserID, RoleID),
    CONSTRAINT FK_UserRoles_Users FOREIGN KEY (UserID) REFERENCES Users(UserID),
    CONSTRAINT FK_UserRoles_Roles FOREIGN KEY (RoleID) REFERENCES Roles(RoleID)
);
GO

-- UserLogs: ghi sự kiện (login fail/success, đổi mật khẩu, lock/unlock)
CREATE TABLE UserLogs (
    LogID INT IDENTITY PRIMARY KEY,
    UserID INT NULL,
    Username VARCHAR(50),
    Action NVARCHAR(200),
    ActionTime DATETIME DEFAULT GETDATE(),
    IPAddress VARCHAR(50) NULL
);
GO

-- LoginAttempts: theo dõi số lần đăng nhập sai để lock account
CREATE TABLE LoginAttempts (
    AttemptID INT IDENTITY PRIMARY KEY,
    UserID INT NULL,
    Username VARCHAR(50),
    AttemptTime DATETIME DEFAULT GETDATE(),
    WasSuccessful BIT,
    IPAddress VARCHAR(50) NULL
);
GO

-- =============================================
-- 4. DỮ LIỆU MẪU NHỎ
-- =============================================
BEGIN TRANSACTION;

INSERT INTO SanBay(MaSanBay, TenSanBay, ThanhPho) VALUES
('SBN01', N'Sân bay Nội Bài', N'Hà Nội'),
('SGN01', N'Sân bay Tân Sơn Nhất', N'Hồ Chí Minh'),
('DAD01', N'Sân bay Đà Nẵng', N'Đà Nẵng');

INSERT INTO MayBay(MaMayBay, HangMayBay, TongSoGhe) VALUES
('MB001', N'Boeing 737', 150),
('MB002', N'Airbus A320', 180);

-- tạm chưa thêm chuyến bay vì trigger tạo vé sẽ dùng dữ liệu MayBay
-- Thêm Roles mặc định
INSERT INTO Roles(RoleName, Description) VALUES
('Admin', N'Quản trị toàn hệ thống'),
('NhanVien', N'Nhân viên bán vé'),
('KhachHang', N'Người dùng đặt vé');

COMMIT;
GO

-- =============================================
-- 5. HÀM (FUNCTION) HỖ TRỢ
-- =============================================

-- 5.1 Hash password (SHA2_256)
CREATE FUNCTION fn_HashPassword(@pwd NVARCHAR(400))
RETURNS VARBINARY(32)
AS
BEGIN
    RETURN HASHBYTES('SHA2_256', CONVERT(NVARCHAR(400), @pwd));
END;
GO

-- 5.2 Tính tiền sau thuế (ví dụ 8%)
CREATE FUNCTION fn_TinhTienSauThue(@GiaCoBan DECIMAL(12,2))
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN ROUND(@GiaCoBan * 1.08, 0); -- làm tròn đồng
END;
GO

-- 5.3 Kiểm tra vé còn (bit)
CREATE FUNCTION fn_VeCon(@MaVe INT)
RETURNS BIT
AS
BEGIN
    DECLARE @kq BIT = 0;
    IF EXISTS(SELECT 1 FROM Ve WHERE MaVe = @MaVe AND TrangThai = N'Chưa bán')
        SET @kq = 1;
    RETURN @kq;
END;
GO

-- =============================================
-- 6. TRIGGER: khi tạo ChuyenBay -> tự sinh đủ số vé theo TongSoGhe của MayBay
-- =============================================
CREATE TRIGGER trg_TaoVeKhiTaoChuyenBay
ON ChuyenBay
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaChuyenBay CHAR(6);
    DECLARE @MaMayBay CHAR(5);
    DECLARE @TongSoGhe INT;
    DECLARE @GiaCoBan DECIMAL(12,2);
    DECLARE @i INT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT i.MaChuyenBay, i.MaMayBay, i.GiaVeCoBan
        FROM inserted i;

    OPEN cur;
    FETCH NEXT FROM cur INTO @MaChuyenBay, @MaMayBay, @GiaCoBan;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @TongSoGhe = TongSoGhe FROM MayBay WHERE MaMayBay = @MaMayBay;

        IF @TongSoGhe IS NULL
            SET @TongSoGhe = 0;

        SET @i = 1;
        WHILE @i <= @TongSoGhe
        BEGIN
            INSERT INTO Ve(MaChuyenBay, HangVe, GiaVe, TrangThai, SoCho)
            VALUES (@MaChuyenBay, N'Economy', @GiaCoBan, N'Chưa bán', @i);

            SET @i = @i + 1;
        END

        FETCH NEXT FROM cur INTO @MaChuyenBay, @MaMayBay, @GiaCoBan;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO

-- =============================================
-- 7. TRIGGER: ghi log khi IsLocked thay đổi
-- =============================================
CREATE TRIGGER trg_LogUserLockChange
ON Users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO UserLogs(UserID, Username, Action)
    SELECT i.UserID, i.Username,
        CASE WHEN d.IsLocked = 0 AND i.IsLocked = 1 THEN N'Account Locked'
             WHEN d.IsLocked = 1 AND i.IsLocked = 0 THEN N'Account Unlocked'
             ELSE N'User UPDATE' END
    FROM inserted i
    JOIN deleted d ON i.UserID = d.UserID
    WHERE ISNULL(d.IsLocked,0) <> ISNULL(i.IsLocked,0);
END;
GO

-- =============================================
-- 8. VIEWS
-- =============================================

CREATE VIEW vw_DanhSachKhachHang AS
SELECT MaKH, HoTen, GioiTinh, NgaySinh, SoDienThoai, Email, CCCD
FROM KhachHang;
GO

CREATE VIEW vw_ThongTinChuyenBay AS
SELECT 
    cb.MaChuyenBay,
    cb.MaMayBay,
    mb.HangMayBay,
    cb.SanBayDi,
    sb1.TenSanBay AS TenSanBayDi,
    cb.SanBayDen,
    sb2.TenSanBay AS TenSanBayDen,
    cb.NgayGioDi,
    cb.NgayGioDen,
    cb.GiaVeCoBan
FROM ChuyenBay cb
JOIN MayBay mb ON cb.MaMayBay = mb.MaMayBay
JOIN SanBay sb1 ON cb.SanBayDi = sb1.MaSanBay
JOIN SanBay sb2 ON cb.SanBayDen = sb2.MaSanBay;
GO

CREATE VIEW vw_DanhSachVe AS
SELECT 
    v.MaVe,
    v.MaChuyenBay,
    v.HangVe,
    v.GiaVe,
    v.TrangThai,
    v.SoCho,
    cb.NgayGioDi,
    cb.NgayGioDen
FROM Ve v
JOIN ChuyenBay cb ON v.MaChuyenBay = cb.MaChuyenBay;
GO

CREATE VIEW vw_ThongTinDatVe AS
SELECT 
    dv.MaDatVe,
    dv.NgayDat,
    dv.TongTien,
    kh.MaKH,
    kh.HoTen,
    v.MaVe,
    v.HangVe,
    cb.MaChuyenBay,
    cb.NgayGioDi
FROM DatVe dv
JOIN KhachHang kh ON dv.MaKH = kh.MaKH
JOIN Ve v ON dv.MaVe = v.MaVe
JOIN ChuyenBay cb ON v.MaChuyenBay = cb.MaChuyenBay;
GO

CREATE VIEW vw_UserPermissions AS
SELECT 
    u.UserID,
    u.Username,
    u.FullName,
    r.RoleName,
    r.Description,
    ur.AssignedAt
FROM Users u
LEFT JOIN UserRoles ur ON u.UserID = ur.UserID
LEFT JOIN Roles r ON ur.RoleID = r.RoleID;
GO

-- =============================================
-- 9. STORED PROCEDURES - CHỨC NĂNG CHÍNH
-- =============================================

-- 9.1 Thêm Khách Hàng
CREATE PROCEDURE sp_ThemKhachHang
    @HoTen NVARCHAR(100),
    @GioiTinh NVARCHAR(10) = NULL,
    @NgaySinh DATE = NULL,
    @SoDT VARCHAR(15) = NULL,
    @Email NVARCHAR(100) = NULL,
    @CCCD VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO KhachHang(HoTen,GioiTinh,NgaySinh,SoDienThoai,Email,CCCD)
    VALUES (@HoTen,@GioiTinh,@NgaySinh,@SoDT,@Email,@CCCD);
END;
GO

-- 9.2 Tạo chuyến bay
CREATE PROCEDURE sp_ThemChuyenBay
    @MaChuyenBay CHAR(6),
    @MaMayBay CHAR(5),
    @SanBayDi CHAR(5),
    @SanBayDen CHAR(5),
    @NgayGioDi DATETIME,
    @NgayGioDen DATETIME,
    @GiaVeCoBan DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO ChuyenBay(MaChuyenBay, MaMayBay, SanBayDi, SanBayDen, NgayGioDi, NgayGioDen, GiaVeCoBan)
    VALUES (@MaChuyenBay, @MaMayBay, @SanBayDi, @SanBayDen, @NgayGioDi, @NgayGioDen, @GiaVeCoBan);
    -- Trigger trg_TaoVeKhiTaoChuyenBay sẽ tạo vé tự động dựa trên TongSoGhe
END;
GO

-- 9.3 Đặt vé (có kiểm tra)
CREATE PROCEDURE sp_DatVe
    @MaKH INT,
    @MaVe INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_VeCon(@MaVe) = 0
    BEGIN
        RAISERROR(N'Vé này đã bán hoặc không tồn tại!', 16, 1);
        RETURN;
    END;

    DECLARE @gia DECIMAL(12,2);
    SELECT @gia = GiaVe FROM Ve WHERE MaVe=@MaVe;

    DECLARE @tong DECIMAL(12,2) = dbo.fn_TinhTienSauThue(@gia);

    INSERT INTO DatVe(MaKH, MaVe, TongTien)
    VALUES (@MaKH, @MaVe, @tong);

    UPDATE Ve SET TrangThai = N'Đã bán' WHERE MaVe = @MaVe;
END;
GO

-- 9.4 Hủy vé theo MaDatVe
CREATE PROCEDURE sp_HuyVe
    @MaDatVe INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaVe INT;
    SELECT @MaVe = MaVe FROM DatVe WHERE MaDatVe = @MaDatVe;

    IF @MaVe IS NULL
    BEGIN
        RAISERROR(N'Không tìm thấy đặt vé!', 16, 1);
        RETURN;
    END;

    DELETE FROM DatVe WHERE MaDatVe = @MaDatVe;
    UPDATE Ve SET TrangThai = N'Chưa bán' WHERE MaVe = @MaVe;
END;
GO

-- =============================================
-- 10. STORED PROCEDURES - QUẢN LÝ NGƯỜI DÙNG & QUYỀN
-- =============================================

-- 10.1 Tạo user (kiểm tra complexity trước khi hash)
CREATE PROCEDURE sp_CreateUser
    @Username VARCHAR(50),
    @Password NVARCHAR(400),
    @FullName NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS(SELECT 1 FROM Users WHERE Username = @Username)
    BEGIN
        RAISERROR(N'Tài khoản đã tồn tại!', 16, 1);
        RETURN;
    END;

    -- Password complexity: tối thiểu 6 ký tự, có số, có chữ
    IF LEN(@Password) < 6 OR @Password NOT LIKE '%[0-9]%' OR @Password NOT LIKE '%[A-Za-z]%'
    BEGIN
        RAISERROR(N'Mật khẩu quá yếu! Phải có chữ và số, tối thiểu 6 ký tự.', 16, 1);
        RETURN;
    END;

    DECLARE @hash VARBINARY(32) = dbo.fn_HashPassword(@Password);

    INSERT INTO Users(Username, PasswordHash, FullName)
    VALUES (@Username, @hash, @FullName);

    INSERT INTO UserLogs(UserID, Username, Action)
    VALUES (SCOPE_IDENTITY(), @Username, N'Create User');
END;
GO

-- 10.2 Đổi mật khẩu (validate + hash)
CREATE PROCEDURE sp_ChangePassword
    @UserID INT,
    @OldPassword NVARCHAR(400),
    @NewPassword NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @dbHash VARBINARY(32);
    SELECT @dbHash = PasswordHash FROM Users WHERE UserID = @UserID;

    IF @dbHash IS NULL
    BEGIN
        RAISERROR(N'User không tồn tại', 16, 1);
        RETURN;
    END;

    IF @dbHash <> dbo.fn_HashPassword(@OldPassword)
    BEGIN
        RAISERROR(N'Mật khẩu cũ không đúng', 16, 1);
        RETURN;
    END;

    IF LEN(@NewPassword) < 6 OR @NewPassword NOT LIKE '%[0-9]%' OR @NewPassword NOT LIKE '%[A-Za-z]%'
    BEGIN
        RAISERROR(N'Mật khẩu mới quá yếu! Phải có chữ và số, tối thiểu 6 ký tự.', 16, 1);
        RETURN;
    END;

    UPDATE Users SET PasswordHash = dbo.fn_HashPassword(@NewPassword) WHERE UserID = @UserID;

    INSERT INTO UserLogs(UserID, Username, Action)
    SELECT @UserID, Username, N'Change Password' FROM Users WHERE UserID = @UserID;
END;
GO

-- 10.3 Gán role cho user
CREATE PROCEDURE sp_AssignRole
    @UserID INT,
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS(SELECT 1 FROM Users WHERE UserID = @UserID)
    BEGIN
        RAISERROR(N'User không tồn tại', 16, 1);
        RETURN;
    END

    IF NOT EXISTS(SELECT 1 FROM Roles WHERE RoleID = @RoleID)
    BEGIN
        RAISERROR(N'Role không tồn tại', 16, 1);
        RETURN;
    END

    IF EXISTS(SELECT 1 FROM UserRoles WHERE UserID=@UserID AND RoleID=@RoleID)
    BEGIN
        RAISERROR(N'Người dùng đã có quyền này!', 16, 1);
        RETURN;
    END;

    INSERT INTO UserRoles(UserID, RoleID) VALUES (@UserID, @RoleID);

    INSERT INTO UserLogs(UserID, Username, Action)
    SELECT @UserID, u.Username, CONCAT(N'Assign Role ', r.RoleName)
    FROM Users u JOIN Roles r ON r.RoleID = @RoleID
    WHERE u.UserID = @UserID;
END;
GO

-- 10.4 Bỏ role
CREATE PROCEDURE sp_RemoveRole
    @UserID INT,
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM UserRoles WHERE UserID=@UserID AND RoleID=@RoleID;

    INSERT INTO UserLogs(UserID, Username, Action)
    SELECT @UserID, Username, CONCAT(N'Remove Role ', @RoleID) FROM Users WHERE UserID = @UserID;
END;
GO

-- 10.5 Login procedure (ghi log, lockout sau 5 lần sai)
CREATE PROCEDURE sp_Login
    @Username VARCHAR(50),
    @Password NVARCHAR(400),
    @IPAddress VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @uid INT = NULL;
    DECLARE @hash VARBINARY(32) = dbo.fn_HashPassword(@Password);
    DECLARE @dbHash VARBINARY(32);
    DECLARE @isLocked BIT = 0;

    SELECT @uid = UserID, @dbHash = PasswordHash, @isLocked = IsLocked FROM Users WHERE Username = @Username;

    IF @uid IS NULL
    BEGIN
        -- Ghi attempt không có user
        INSERT INTO LoginAttempts(UserID, Username, WasSuccessful, IPAddress) VALUES (NULL, @Username, 0, @IPAddress);
        INSERT INTO UserLogs(UserID, Username, Action, IPAddress) VALUES (NULL, @Username, N'Login failed - user not found', @IPAddress);
        RAISERROR(N'User không tồn tại', 16, 1);
        RETURN;
    END

    IF @isLocked = 1
    BEGIN
        INSERT INTO LoginAttempts(UserID, Username, WasSuccessful, IPAddress) VALUES (@uid, @Username, 0, @IPAddress);
        INSERT INTO UserLogs(UserID, Username, Action, IPAddress) VALUES (@uid, @Username, N'Login failed - account locked', @IPAddress);
        RAISERROR(N'Tài khoản đang bị khóa', 16, 1);
        RETURN;
    END

    IF @dbHash = @hash
    BEGIN
        -- success
        INSERT INTO LoginAttempts(UserID, Username, WasSuccessful, IPAddress) VALUES (@uid, @Username, 1, @IPAddress);
        INSERT INTO UserLogs(UserID, Username, Action, IPAddress) VALUES (@uid, @Username, N'Login success', @IPAddress);
        -- Optionally reset counters or do nothing
        SELECT N'OK' AS Result, @uid AS UserID;
    END
    ELSE
    BEGIN
        -- failed
        INSERT INTO LoginAttempts(UserID, Username, WasSuccessful, IPAddress) VALUES (@uid, @Username, 0, @IPAddress);
        INSERT INTO UserLogs(UserID, Username, Action, IPAddress) VALUES (@uid, @Username, N'Login failed - wrong password', @IPAddress);

        -- count last N failed attempts (ví dụ: trong 24h hoặc tổng)
        DECLARE @fails INT;
        SELECT @fails = COUNT(*) FROM LoginAttempts
        WHERE UserID = @uid AND WasSuccessful = 0 AND AttemptTime >= DATEADD(HOUR, -24, GETDATE());

        -- Nếu >=5 thì khóa tài khoản
        IF @fails >= 5
        BEGIN
            UPDATE Users SET IsLocked = 1 WHERE UserID = @uid;
            INSERT INTO UserLogs(UserID, Username, Action, IPAddress) VALUES (@uid, @Username, N'Account locked due to too many failed logins', @IPAddress);
            RAISERROR(N'Tài khoản đã bị khóa do đăng nhập sai quá nhiều lần', 16, 1);
            RETURN;
        END

        RAISERROR(N'Mật khẩu sai', 16, 1);
    END
END;
GO

-- 10.6 Unlock tài khoản (Admin)
CREATE PROCEDURE sp_UnlockUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Users SET IsLocked = 0 WHERE UserID = @UserID;
    INSERT INTO UserLogs(UserID, Username, Action)
    SELECT @UserID, Username, N'Admin Unlock' FROM Users WHERE UserID = @UserID;
END;
GO

-- =============================================
-- 11. CONTROLS / UTILITY SProcedure: TẠO ADMIN MẪU (dùng 1 lần)
-- =============================================
CREATE PROCEDURE sp_CreateAdminSample
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS(SELECT 1 FROM Users WHERE Username = 'admin')
    BEGIN
        DECLARE @pwd NVARCHAR(400) = 'Admin123'; -- bạn nên đổi khi deploy
        INSERT INTO Users(Username, PasswordHash, FullName)
        VALUES ('admin', dbo.fn_HashPassword(@pwd), N'Administrator');

        DECLARE @uid INT = SCOPE_IDENTITY();

        DECLARE @roleAdmin INT;
        SELECT @roleAdmin = RoleID FROM Roles WHERE RoleName = 'Admin';

        IF @roleAdmin IS NOT NULL
            INSERT INTO UserRoles(UserID, RoleID) VALUES (@uid, @roleAdmin);

        INSERT INTO UserLogs(UserID, Username, Action) VALUES (@uid, 'admin', N'Create default admin');
    END
    ELSE
    BEGIN
        RAISERROR(N'Admin đã tồn tại', 10, 1);
    END
END;
GO

-- =============================================
-- 12. TÙY CHỌN: TẠO CHUYẾN BAY MẪU (để trigger tạo vé)
-- =============================================
-- Bạn có thể gọi sp_ThemChuyenBay để tạo chuyến và trigger trg_TaoVeKhiTaoChuyenBay sẽ sinh vé
-- Ví dụ (bỏ comment để chạy):
/*
EXEC sp_ThemChuyenBay
    @MaChuyenBay = 'CB0001',
    @MaMayBay = 'MB001',
    @SanBayDi = 'SBN01',
    @SanBayDen = 'SGN01',
    @NgayGioDi = '2025-12-01 07:00',
    @NgayGioDen = '2025-12-01 09:30',
    @GiaVeCoBan = 1200000.00;
*/
GO

-- =============================================
-- 13. INDEX / TUNE (tuỳ chọn - thêm index cho hiệu năng tra cứu)
-- =============================================
CREATE INDEX IX_Ve_MaChuyenBay ON Ve(MaChuyenBay);
CREATE INDEX IX_DatVe_MaKH ON DatVe(MaKH);
CREATE INDEX IX_LoginAttempts_Username ON LoginAttempts(Username);
GO

-- =============================================
-- 14. Các ví dụ gọi (commented) - hướng dẫn sử dụng
-- =============================================
/*
-- Tạo admin mẫu
EXEC sp_CreateAdminSample;

-- Tạo user mới
EXEC sp_CreateUser @Username='nv1', @Password='Nv12345', @FullName=N'Nhân viên 1';

-- Gán role
DECLARE @uid INT; SELECT @uid = UserID FROM Users WHERE Username='nv1';
DECLARE @roleid INT; SELECT @roleid = RoleID FROM Roles WHERE RoleName='NhanVien';
EXEC sp_AssignRole @UserID=@uid, @RoleID=@roleid;

-- Đăng nhập
EXEC sp_Login @Username='nv1', @Password='Nv12345', @IPAddress='192.168.1.10';

-- Tạo chuyến bay (sẽ tự sinh vé)
EXEC sp_ThemChuyenBay @MaChuyenBay='CB0002', @MaMayBay='MB001', @SanBayDi='SBN01', @SanBayDen='DAD01',
    @NgayGioDi='2025-12-05 14:00', @NgayGioDen='2025-12-05 15:20', @GiaVeCoBan=900000;

-- Đặt vé:
-- Giả sử MaVe = 1, MaKH = 1
EXEC sp_DatVe @MaKH=1, @MaVe=1;
*/

-- ===================================================
-- KẾT THÚC SCRIPT
-- ===================================================

