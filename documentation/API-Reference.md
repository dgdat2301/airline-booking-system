# 🛠️ API REFERENCE - STORED PROCEDURES & FUNCTIONS

## 📊 DANH MỤC STORED PROCEDURES

### 👥 QUẢN LÝ KHÁCH HÀNG

#### `sp_ThemKhachHang`
**Mô tả:** Thêm khách hàng mới vào hệ thống

**Parameters:**
```sql
@HoTen NVARCHAR(100),
@GioiTinh NVARCHAR(10) = NULL,
@NgaySinh DATE = NULL,
@SoDT VARCHAR(15) = NULL,
@Email NVARCHAR(100) = NULL,
@CCCD VARCHAR(20) = NULL
