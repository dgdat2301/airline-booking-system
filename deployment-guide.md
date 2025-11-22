# HƯỚNG DẪN TRIỂN KHAI

## 1. Yêu cầu hệ thống
- SQL Server 2016+
- SQL Server Management Studio

## 2. Các bước triển khai
1. Mở SSMS
2. Kết nối đến SQL Server
3. Mở file `database.sql`
4. Chạy toàn bộ script
5. Chạy `sample-data.sql` để thêm dữ liệu mẫu

## 3. Kiểm tra
```sql
-- Kiểm tra các bảng
SELECT * FROM vw_DanhSachKhachHang;
SELECT * FROM vw_ThongTinChuyenBay;

-- Test login
EXEC sp_Login @Username='admin', @Password='Admin123';
