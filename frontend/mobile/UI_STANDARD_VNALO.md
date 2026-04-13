# VNALO Mobile UI Standard & Premium Layering Law
*Phiên bản: 1.0 (Standardization Audit Recap)*

Tài liệu này quy chuẩn hóa toàn bộ hệ thống màu sắc và phân lớp (Layering) cho ứng dụng VNALO Mobile, nhằm đảm bảo tính nhất quán cao nhất và trải nghiệm Premium (tương tự chuẩn Zalo).

---

## 1. Hệ thống Token Màu (Standard Tokens)

Luôn sử dụng các Token này thay vì mã màu Hexa cứng (`0xFF...`) hoặc các màu hệ thống của Flutter (`Colors.white`, `Colors.black`).

### 1.1. Dark Mode (Chế độ Tối)
| Component | Token / Value | Mục đích |
| :--- | :--- | :--- |
| **Scaffold BG** | `DarkColors.scaffold` (`0xFF000000`) | Nền tảng sâu nhất (Layer 0). |
| **Item/Surface** | `DarkColors.surface` (`0xFF131313`) | Nền cho Card, ListTile, Input, Modal (Layer 1). |
| **AppBar/Header** | `DarkColors.appBarBg` (`0xFF222222`) | Nền cho thanh tiêu chuẩn, Header nổi bật (Layer 2). |
| **Text Primary** | `DarkColors.textPrimary` (`0xFFFFFFFF`) | Văn bản tiêu đề, nội dung chính. |
| **Text Secondary** | `DarkColors.textSecondary` (`0xFFAAAAAA`) | Văn bản phụ, thời gian, mô tả. |
| **Divider** | `DarkColors.divider` (`0xFF1F1F1F`) | Đường kẻ chia tách các thành phần. |

### 1.2. Light Mode (Chế độ Sáng)
| Component | Token / Value | Mục đích |
| :--- | :--- | :--- |
| **Scaffold BG** | `AppColors.sectionBackground` (`0xFFF3F4F6`) | Nền tảng bên dưới các thẻ. |
| **Item/Surface** | `Colors.white` (`0xFFFFFFFF`) | Nền cho các thành phần item. |
| **AppBar/Header** | `AppColors.appBarGradient` | Gradient Xanh đặc trưng của VNALO. |
| **Text Primary** | `LightColors.textPrimary` (`0xFF1A1A1A`) | Văn bản chính. |
| **Text Secondary** | `LightColors.textSecondary` (`0xFF757575`) | Văn bản phụ. |

---

## 2. Quy luật Phân lớp (Premium Layering Law)

Trong Dark Mode, để tạo độ sâu và cảm giác cao cấp, ứng dụng phải tuân thủ phân lớp độ sáng tuyệt đối:
**AppBar (Sáng nhất) > Item Section (Trung bình) > Scaffold Background (Tối nhất - Đen tuyền)**

### 2.1. AppBar Layering
- **Light Mode**: Sử dụng `flexibleSpace` với `AppColors.appBarGradient`.
- **Dark Mode**: 
  - `backgroundColor`: `DarkColors.appBarBg` (Xám đen sáng).
  - `forceMaterialTransparency`: `false` (Để hiện màu AppBar thay vì nhìn xuyên qua nền).
  - **Tuyệt đối không dùng Gradient** trong Dark Mode để tránh lỗi "AppBar bẩn".

### 2.2. Modal & Popup Layering
- Toàn bộ Dialog, BottomSheet phải có `backgroundColor: isDarkMode ? DarkColors.surface : Colors.white`.
- Không được để nền Modal cùng màu với nền Scaffold (Đen tuyền) vì sẽ bị nuốt mất khối.

---

## 3. Quy tắc Icon & "Dirty UI" Prevention

Để tránh tình trạng UI "bẩn" (icon đen trên nền tối, icon trắng trên nền sáng chói):

1. **Icon trong Dark Mode**: 
   - Tuyệt đối không dùng `Colors.black`, `Colors.black87`, `Colors.black54`.
   - Sử dụng `Colors.white` hoặc `DarkColors.textPrimary`.
2. **Input Fields**:
   - Nền Input trong Dark Mode phải là `DarkColors.surface` hoặc trắng mờ (`white10`).
   - Không được để nền trắng cứng (`Colors.white`) trong ô nhập liệu của Dark Mode.
3. **Divider**:
   - Trong Dark Mode, sử dụng `DarkColors.divider` hoặc `Colors.white10`.
   - Màu sắc phải tinh tế, tránh các đường kẻ màu trắng quá gắt.

---

## 4. Tài liệu tham khảo Code
- Theme chính: [app_theme.dart](file:///d:/Download/Project/cnm-vnalo/frontend/mobile/lib/core/theme/app_theme.dart)
- Hệ thống màu: [app_colors.dart](file:///d:/Download/Project/cnm-vnalo/frontend/mobile/lib/core/theme/app_colors.dart)

> [!IMPORTANT]
> Toàn bộ Code mới phải sử dụng `final isDarkMode = Theme.of(context).brightness == Brightness.dark;` để gán màu sắc adaptive, thay vì fix cứng một màu duy nhất.
