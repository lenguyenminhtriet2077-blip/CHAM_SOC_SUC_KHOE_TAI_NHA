--
-- PostgreSQL database dump
--

\restrict Dym2swXWitmRtnCnI5YkQMsJvRo9SIhlE0uOnZWQTZuPabR66Gxtxq6gdp7foyw

-- Dumped from database version 17.9
-- Dumped by pg_dump version 17.9

-- Started on 2026-05-16 17:43:28

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 263 (class 1255 OID 25465)
-- Name: fn_ai_phantichcamxuc(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_ai_phantichcamxuc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. TÍCH CỰC (Tương ứng SoSao = 4, 5)
    IF NEW.SoSao >= 4 
       OR NEW.NoiDung ILIKE ANY (ARRAY[
          '%Tuyệt vời%', '%Rất hài lòng%', '%sạch sẽ%', '%hiện đại%', 
          '%Dịch vụ tốt%', '%tận tâm%', '%Hài lòng%'
       ]) 
    THEN
        NEW.AI_PhanTichCamXuc := 'Tích cực';

    -- 2. TIÊU CỰC (Tương ứng SoSao = 1, 2)
    ELSIF NEW.SoSao <= 2 
       OR NEW.NoiDung ILIKE ANY (ARRAY[
          '%Không hài lòng%', '%chưa tốt%', '%thất vọng%', 
          '%quá tệ%', '%không quay lại%'
       ]) 
    THEN
        NEW.AI_PhanTichCamXuc := 'Tiêu cực';

    -- 3. TRUNG TÍNH (Tương ứng SoSao = 3)
    -- Bao gồm các sắc thái về thời gian chờ và mật độ khách
    ELSE
        NEW.AI_PhanTichCamXuc := 'Trung tính';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 236 (class 1255 OID 25463)
-- Name: fn_ai_phantichsuckhoe(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_ai_phantichsuckhoe() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Giả lập AI: Nếu Huyết áp cao + Nhịp tim nhanh + Người cao tuổi
    IF (NEW.NhipTim > 100 AND NEW.NhietDo > 38.5) THEN
        NEW.AI_CanhBaoRuiRo := 'CẢNH BÁO AI: Nguy cơ nhiễm trùng huyết hoặc suy tim cấp. Cần theo dõi đặc biệt.';
        NEW.AI_DoTinCay := 0.92;
    ELSIF (NEW.NhietDo > 39.0) THEN
        NEW.AI_CanhBaoRuiRo := 'CẢNH BÁO AI: Nguy cơ sốt co giật.';
        NEW.AI_DoTinCay := 0.85;
    ELSE
        NEW.AI_CanhBaoRuiRo := 'AI: Chỉ số trong ngưỡng an toàn.';
        NEW.AI_DoTinCay := 0.95;
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 237 (class 1255 OID 17235)
-- Name: fn_canhcaonhanvienhuylich(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_canhcaonhanvienhuylich() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_ThoiGianConLai INTERVAL;
BEGIN
    -- 1. Chỉ xử lý nếu trạng thái mới bị đổi thành 'Đã hủy'
    IF NEW.TrangThai = 'Đã hủy' AND OLD.TrangThai != 'Đã hủy' THEN
        
        -- 2. Tính xem còn bao nhiêu phút nữa thì đến giờ hẹn
        -- Lấy (Giờ bắt đầu khám) trừ đi (Giờ hiện tại lúc bấm hủy)
        v_ThoiGianConLai := NEW.ThoiGianBatDau - CURRENT_TIMESTAMP;

        -- 3. Nếu thời gian còn lại ít hơn 2 tiếng (2 hours)
        IF v_ThoiGianConLai < INTERVAL '2 hours' THEN
            
            -- 4. Đánh dấu cảnh cáo vào hồ sơ nhân viên
            -- Ở đây mình sẽ giả sử bạn ghi chú vào cột 'GhiChu' hoặc giảm 'DiemUyTin'
            UPDATE NHAN_VIEN_Y_TE
            SET DiemUyTin = DiemUyTin - 0.5 -- Trừ 0.5 điểm uy tín vì hủy gấp
            WHERE MaNhanVien = NEW.MaNhanVien;
            
            -- Thông báo cho người dùng biết
            RAISE NOTICE 'Nhân viên bị trừ điểm uy tín do hủy lịch sát giờ (dưới 2 tiếng).';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 258 (class 1255 OID 17266)
-- Name: fn_doanhthungay(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_doanhthungay(p_ngay date) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_Tong DECIMAL;
BEGIN
    -- Ép kiểu ::DATE để đảm bảo khớp chính xác ngày
    SELECT SUM(TongThanhToan) INTO v_Tong 
    FROM HOA_DON 
    WHERE NgayLap::DATE = p_Ngay;
    
    RETURN COALESCE(v_Tong, 0);
END;
$$;


--
-- TOC entry 253 (class 1255 OID 17242)
-- Name: fn_gioihanhosobenhnhan(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_gioihanhosobenhnhan() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT COUNT(*) FROM BENH_NHAN WHERE MaKhachHang = NEW.MaKhachHang) >= 10 THEN
        RAISE EXCEPTION 'Mỗi khách hàng chỉ được quản lý tối đa 10 hồ sơ bệnh nhân';
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 238 (class 1255 OID 17236)
-- Name: fn_khoaketquakham(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_khoaketquakham() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_ThoiGianHoanThanh TIMESTAMP;
BEGIN
    SELECT ThoiGianKetThuc INTO v_ThoiGianHoanThanh 
    FROM LICH_HEN WHERE MaLichHen = OLD.MaLichHen;

    IF v_ThoiGianHoanThanh IS NOT NULL AND (CURRENT_TIMESTAMP - v_ThoiGianHoanThanh) > INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'Đã quá 24h kể từ khi hoàn thành, không thể sửa kết quả khám';
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 239 (class 1255 OID 17237)
-- Name: fn_kiemtrahosinhkhoasan(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_kiemtrahosinhkhoasan() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_LoaiNhanSu VARCHAR(50);
    v_TenChuyenKhoa VARCHAR(100);
BEGIN
    -- 1. Lấy loại nhân sự của nhân viên đang được gán chuyên khoa
    SELECT LoaiNhanSu INTO v_LoaiNhanSu 
    FROM NHAN_VIEN_Y_TE 
    WHERE MaNhanVien = NEW.MaNhanVien;

    -- 2. Lấy tên chuyên khoa đang được gán
    SELECT TenChuyenKhoa INTO v_TenChuyenKhoa 
    FROM CHUYEN_KHOA 
    WHERE MaChuyenKhoa = NEW.MaChuyenKhoa;

    -- 3. Kiểm tra logic: Nếu là Hộ sinh mà không phải khoa Sản thì báo lỗi
    IF v_LoaiNhanSu = 'Hộ sinh' AND v_TenChuyenKhoa NOT LIKE '%Sản%' THEN
        RAISE EXCEPTION 'Lỗi: Nhân viên Hộ sinh chỉ được thuộc chuyên khoa Phụ sản!';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 240 (class 1255 OID 17238)
-- Name: fn_kiemtraluongtrangthai(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_kiemtraluongtrangthai() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Nếu là cập nhật trạng thái
    IF OLD.TrangThai = 'Chờ' AND NEW.TrangThai NOT IN ('Đã phân công', 'Đã hủy') THEN
        RAISE EXCEPTION 'Từ trạng thái Chờ chỉ được chuyển sang Đã phân công hoặc Đã hủy';
    ELSIF OLD.TrangThai = 'Đã phân công' AND NEW.TrangThai NOT IN ('Đang thực hiện', 'Đã hủy') THEN
        RAISE EXCEPTION 'Phải chuyển sang Đang thực hiện trước khi Hoàn thành';
    ELSIF OLD.TrangThai = 'Hoàn thành' THEN
        RAISE EXCEPTION 'Lịch hẹn đã hoàn thành không được phép sửa trạng thái';
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 256 (class 1255 OID 17263)
-- Name: fn_kiemtranhanvienranh(character varying, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_kiemtranhanvienranh(p_manv character varying, p_batdau timestamp without time zone, p_ketthuc timestamp without time zone) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Nếu tồn tại bất kỳ lịch hẹn nào chồng lấn thì trả về FALSE
    IF EXISTS (
        SELECT 1 FROM LICH_HEN 
        WHERE MaNhanVien = p_MaNV 
        AND TrangThai != 'Đã hủy'
        AND (p_BatDau, p_KetThuc) OVERLAPS (ThoiGianBatDau, ThoiGianKetThuc)
    ) THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$;


--
-- TOC entry 252 (class 1255 OID 17240)
-- Name: fn_kiemtratrunglich(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_kiemtratrunglich() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM LICH_HEN 
        WHERE MaNhanVien = NEW.MaNhanVien 
        AND MaLichHen != NEW.MaLichHen
        AND (NEW.ThoiGianBatDau, NEW.ThoiGianKetThuc) OVERLAPS (ThoiGianBatDau, ThoiGianKetThuc)
    ) THEN
        RAISE EXCEPTION 'Nhân viên này đã có lịch hẹn khác trong khoảng thời gian này!';
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 261 (class 1255 OID 17269)
-- Name: fn_mucdokhancap(numeric, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_mucdokhancap(p_nhietdo numeric, p_nhiptim integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic đơn giản: Sốt cao (>39 độ) hoặc nhịp tim quá nhanh (>120) là khẩn cấp
    IF p_NhietDo > 39.0 OR p_NhipTim > 120 THEN
        RETURN 'KHẨN CẤP - ƯU TIÊN 1';
    ELSIF p_NhietDo > 37.5 OR p_NhipTim > 100 THEN
        RETURN 'THEO DÕI - ƯU TIÊN 2';
    ELSE
        RETURN 'BÌNH THƯỜNG';
    END IF;
END;
$$;


--
-- TOC entry 259 (class 1255 OID 17267)
-- Name: fn_phanloainhomtuoi(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_phanloainhomtuoi(p_ngaysinh date) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_Tuoi INTEGER;
BEGIN
    v_Tuoi := EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_NgaySinh));
    
    IF v_Tuoi < 1 THEN RETURN 'Trẻ sơ sinh';
    ELSIF v_Tuoi < 16 THEN RETURN 'Trẻ em';
    ELSIF v_Tuoi < 60 THEN RETURN 'Người trưởng thành';
    ELSE RETURN 'Người cao tuổi';
    END IF;
END;
$$;


--
-- TOC entry 262 (class 1255 OID 17270)
-- Name: fn_tinhgiasauthue(numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_tinhgiasauthue(p_sotien numeric, p_thuesuat numeric DEFAULT 0.08) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN p_SoTien * (1 + p_ThueSuat);
END;
$$;


--
-- TOC entry 260 (class 1255 OID 17268)
-- Name: fn_tinhthoigiankham(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_tinhthoigiankham(p_batdau timestamp without time zone, p_ketthuc timestamp without time zone) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_Phut INTEGER;
BEGIN
    v_Phut := EXTRACT(EPOCH FROM (p_KetThuc - p_BatDau)) / 60;
    RETURN v_Phut || ' phút';
END;
$$;


--
-- TOC entry 255 (class 1255 OID 17262)
-- Name: fn_tinhtuoi(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_tinhtuoi(p_ngaysinh date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_NgaySinh));
END;
$$;


--
-- TOC entry 254 (class 1255 OID 17244)
-- Name: fn_trutonkhovattu(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_trutonkhovattu() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Cập nhật giảm số lượng tồn
    UPDATE VAT_TU_Y_TE 
    SET SoLuongTon = SoLuongTon - NEW.SoLuong
    WHERE MaVatTu = NEW.MaVatTu;

    -- Kiểm tra nếu kho bị âm
    IF (SELECT SoLuongTon FROM VAT_TU_Y_TE WHERE MaVatTu = NEW.MaVatTu) < 0 THEN
        RAISE EXCEPTION 'Số lượng vật tư trong kho không đủ!';
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- TOC entry 257 (class 1255 OID 25493)
-- Name: sp_hoanthanhlichkham(character varying, text, character varying, integer, numeric); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_hoanthanhlichkham(IN p_malichhen character varying, IN p_chandoan text, IN p_huyetap character varying, IN p_nhiptim integer, IN p_nhietdo numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. Cập nhật trạng thái lịch hẹn
    UPDATE public.lich_hen 
    SET TrangThai = 'Hoàn thành', ThoiGianKetThuc = CURRENT_TIMESTAMP
    WHERE MaLichHen = p_malichhen;

    -- 2. Thêm kết quả khám (SỬ DỤNG REPLACE ĐỂ ĐỔI 'LH' THÀNH 'KQ')
    INSERT INTO public.ket_qua_kham (MaKetQua, MaLichHen, ChanDoanSoBo, HuyetAp, NhipTim, NhietDo)
    VALUES (REPLACE(p_malichhen, 'LH', 'KQ'), p_malichhen, p_chandoan, p_huyetap, p_nhiptim, p_nhietdo);

    -- 3. Gọi Procedure tạo hóa đơn
    CALL public.sp_taohoadonthanhtoan(p_malichhen);

END;
$$;


--
-- TOC entry 264 (class 1255 OID 17239)
-- Name: sp_taohoadonthanhtoan(character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_taohoadonthanhtoan(IN p_malichhen character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_tongtiendichvu DECIMAL(15,2) := 0;
    v_tongtienvattu DECIMAL(15,2) := 0;
    v_heso DECIMAL(3,1) := 1.0;
    v_mahoadon character varying(20);
BEGIN
    -- 1. Tính hệ số giờ (Sau 22h) dựa trên cột malichhen và thoigianbatdau (bảng lich_hen)
    SELECT CASE WHEN EXTRACT(HOUR FROM thoigianbatdau) >= 22 THEN 1.2 ELSE 1.0 END
    INTO v_heso FROM public.lich_hen WHERE malichhen = p_malichhen;

    -- 2. Tính tiền dịch vụ từ bảng dich_vu nối với lich_hen
    SELECT COALESCE(dv.dongiatieuchuan * v_heso, 0) INTO v_tongtiendichvu
    FROM public.dich_vu dv JOIN public.lich_hen lh ON dv.madichvu = lh.madichvu
    WHERE lh.malichhen = p_malichhen;

    -- 3. Tính tiền vật tư từ bảng chi_tiet_vat_tu nối với ket_qua_kham
    SELECT COALESCE(SUM(ct.soluong * ct.dongiathoidiem), 0) INTO v_tongtienvattu
    FROM public.chi_tiet_vat_tu ct JOIN public.ket_qua_kham kq ON ct.maketqua = kq.maketqua
    WHERE kq.malichhen = p_malichhen;

    -- 4. Tạo mã hóa đơn format HDKQxxx (Ví dụ: LH301 -> HDKQ301) sử dụng toán tử || tự động như bạn muốn
    v_mahoadon := 'HD' || REPLACE(p_malichhen, 'LH', 'KQ');

    -- 5. Lệnh INSERT CHUẨN XÁC: 
    -- Tuyệt đối KHÔNG liệt kê cột 'tongthanhtoan' ở đây vì hệ thống tự tính toán rồi
    INSERT INTO public.hoa_don (mahoadon, malichhen, tongtiendichvu, tongtienvattu, phiphatsinh, ngaylap)
    VALUES (
        v_mahoadon, 
        p_malichhen, 
        v_tongtiendichvu, 
        v_tongtienvattu,
        0, -- phiphatsinh mặc định ban đầu là 0
        CURRENT_TIMESTAMP
    );
END;
$$;


--
-- TOC entry 228 (class 1259 OID 17227)
-- Name: admin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin (
    maadmin character varying(20) NOT NULL,
    tendangnhap character varying(50) NOT NULL,
    matkhau character varying(255) NOT NULL,
    hoten character varying(100),
    capdo character varying(50) DEFAULT 'Staff'::character varying
);


--
-- TOC entry 218 (class 1259 OID 17065)
-- Name: benh_nhan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.benh_nhan (
    mabenhnhan character varying(20) NOT NULL,
    makhachhang character varying(20) NOT NULL,
    hoten character varying(100) NOT NULL,
    ngaysinh date,
    gioitinh character varying(10),
    nhommau character varying(5),
    diachi character varying(255),
    tiensubenh text,
    ai_goiydichvutieptheo text,
    CONSTRAINT chk_bn_gioitinh CHECK (((gioitinh)::text = ANY ((ARRAY['Nam'::character varying, 'Nữ'::character varying, 'Khác'::character varying])::text[]))),
    CONSTRAINT chk_bn_ngaysinh CHECK ((ngaysinh <= CURRENT_DATE))
);


--
-- TOC entry 225 (class 1259 OID 17174)
-- Name: chi_tiet_vat_tu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chi_tiet_vat_tu (
    maketqua character varying(20) NOT NULL,
    mavattu character varying(20) NOT NULL,
    soluong integer NOT NULL,
    dongiathoidiem numeric(15,2),
    CONSTRAINT chk_ctvt_dongia CHECK ((dongiathoidiem >= (0)::numeric)),
    CONSTRAINT chk_ctvt_soluong CHECK ((soluong > 0))
);


--
-- TOC entry 220 (class 1259 OID 17097)
-- Name: chuyen_khoa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chuyen_khoa (
    machuyenkhoa character varying(20) NOT NULL,
    tenchuyenkhoa character varying(100) NOT NULL
);


--
-- TOC entry 227 (class 1259 OID 17210)
-- Name: danh_gia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.danh_gia (
    madanhgia character varying(20) NOT NULL,
    malichhen character varying(20) NOT NULL,
    sosao integer NOT NULL,
    noidung text,
    lydokhieunai text,
    ngaydanhgia timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ai_phantichcamxuc character varying(50),
    CONSTRAINT chk_dg_logic_khieunai CHECK (((sosao > 2) OR ((sosao <= 2) AND (lydokhieunai IS NOT NULL) AND (lydokhieunai <> ''::text)))),
    CONSTRAINT chk_dg_sao CHECK (((sosao >= 1) AND (sosao <= 5)))
);


--
-- TOC entry 222 (class 1259 OID 17117)
-- Name: dich_vu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dich_vu (
    madichvu character varying(20) NOT NULL,
    tendichvu character varying(200) NOT NULL,
    mota text,
    dongiatieuchuan numeric(15,2) DEFAULT 0,
    thoiluongdukien integer,
    phanloai character varying(100),
    capbacyeucau character varying(100),
    CONSTRAINT chk_dv_gia CHECK ((dongiatieuchuan >= (0)::numeric)),
    CONSTRAINT chk_dv_thoiluong CHECK ((thoiluongdukien > 0))
);


--
-- TOC entry 226 (class 1259 OID 17191)
-- Name: hoa_don; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hoa_don (
    mahoadon character varying(20) NOT NULL,
    malichhen character varying(20) NOT NULL,
    tongtiendichvu numeric(15,2) DEFAULT 0,
    tongtienvattu numeric(15,2) DEFAULT 0,
    phiphatsinh numeric(15,2) DEFAULT 0,
    tongthanhtoan numeric(15,2) GENERATED ALWAYS AS (((tongtiendichvu + tongtienvattu) + phiphatsinh)) STORED,
    ngaylap timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    phuongthucthanhtoan character varying(50),
    trangthaithanhtoan character varying(50) DEFAULT 'Chưa thanh toán'::character varying,
    CONSTRAINT chk_hd_tien CHECK (((tongtiendichvu >= (0)::numeric) AND (tongtienvattu >= (0)::numeric)))
);


--
-- TOC entry 229 (class 1259 OID 17246)
-- Name: ket_qua_kham; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ket_qua_kham (
    maketqua character varying(20) NOT NULL,
    malichhen character varying(20) NOT NULL,
    chandoansobo text,
    huyetap character varying(20),
    nhiptim integer,
    nhietdo numeric(4,1),
    ylenh text,
    ghichu text,
    ai_canhbaoruiro text,
    ai_dotincay numeric(3,2),
    CONSTRAINT chk_kq_nhietdo CHECK (((nhietdo >= (34)::numeric) AND (nhietdo <= (42)::numeric))),
    CONSTRAINT chk_kq_nhiptim CHECK ((nhiptim > 0))
);


--
-- TOC entry 217 (class 1259 OID 17056)
-- Name: khach_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.khach_hang (
    makhachhang character varying(20) NOT NULL,
    hoten character varying(100) NOT NULL,
    sodienthoai character varying(15) NOT NULL,
    email character varying(100),
    matkhau character varying(255) NOT NULL
);


--
-- TOC entry 223 (class 1259 OID 17127)
-- Name: lich_hen; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lich_hen (
    malichhen character varying(20) NOT NULL,
    mabenhnhan character varying(20) NOT NULL,
    madichvu character varying(20) NOT NULL,
    manhanvien character varying(20),
    ngaydat timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    thoigianbatdau timestamp without time zone,
    thoigianketthuc timestamp without time zone,
    diachithuchien character varying(255),
    trangthai character varying(50) DEFAULT 'Chờ'::character varying,
    ai_xacsuatvangmat numeric(3,2),
    ai_thutuuutiendichuyen integer,
    CONSTRAINT chk_lh_trangthai CHECK (((trangthai)::text = ANY ((ARRAY['Chờ'::character varying, 'Đã phân công'::character varying, 'Đang thực hiện'::character varying, 'Hoàn thành'::character varying, 'Đã hủy'::character varying])::text[])))
);


--
-- TOC entry 221 (class 1259 OID 17102)
-- Name: nhan_vien_chuyen_khoa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nhan_vien_chuyen_khoa (
    manhanvien character varying(20) NOT NULL,
    machuyenkhoa character varying(20) NOT NULL
);


--
-- TOC entry 219 (class 1259 OID 17079)
-- Name: nhan_vien_y_te; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nhan_vien_y_te (
    manhanvien character varying(20) NOT NULL,
    hoten character varying(100) NOT NULL,
    cccd character varying(20) NOT NULL,
    sodienthoai character varying(15),
    ngaysinh date,
    loainhansu character varying(50),
    trangthai character varying(50) DEFAULT 'Sẵn sàng'::character varying,
    socchn character varying(50),
    ngaycapcchn date,
    noicapcchn character varying(200),
    ngayhethancchn date,
    sonamkinhnghiem integer DEFAULT 0,
    diemuytin numeric(3,2) DEFAULT 5.0,
    CONSTRAINT chk_nv_kinhnghiem CHECK ((sonamkinhnghiem >= 0)),
    CONSTRAINT chk_nv_loai CHECK (((loainhansu)::text = ANY ((ARRAY['Bác sĩ'::character varying, 'Điều dưỡng'::character varying, 'KTV'::character varying, 'Hộ sinh'::character varying])::text[]))),
    CONSTRAINT chk_nv_trangthai CHECK (((trangthai)::text = ANY ((ARRAY['Sẵn sàng'::character varying, 'Đang bận'::character varying, 'Nghỉ'::character varying])::text[]))),
    CONSTRAINT chk_nv_uytin CHECK (((diemuytin >= (0)::numeric) AND (diemuytin <= (5)::numeric)))
);


--
-- TOC entry 224 (class 1259 OID 17166)
-- Name: vat_tu_y_te; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_tu_y_te (
    mavattu character varying(20) NOT NULL,
    tenvattu character varying(200) NOT NULL,
    dongiahientai numeric(15,2) DEFAULT 0,
    donvitinh character varying(50),
    soluongton integer DEFAULT 0,
    CONSTRAINT chk_vt_ton CHECK ((soluongton >= 0))
);


--
-- TOC entry 235 (class 1259 OID 25486)
-- Name: vw_ai_canhbaosuckhoe; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ai_canhbaosuckhoe AS
 SELECT bn.mabenhnhan,
    bn.hoten,
    kq.chandoansobo,
        CASE
            WHEN (kq.nhietdo > (39)::numeric) THEN 'Nguy cơ cao'::text
            WHEN ((kq.nhietdo >= 37.5) AND (kq.nhietdo <= (39)::numeric)) THEN 'Nguy cơ trung bình'::text
            ELSE 'Ổn định'::text
        END AS muccanhbao
   FROM ((public.benh_nhan bn
     JOIN public.lich_hen lh ON (((bn.mabenhnhan)::text = (lh.mabenhnhan)::text)))
     JOIN public.ket_qua_kham kq ON (((lh.malichhen)::text = (kq.malichhen)::text)));


--
-- TOC entry 234 (class 1259 OID 25479)
-- Name: vw_ai_system_insights; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ai_system_insights AS
 SELECT lh.malichhen,
    bn.hoten AS tenbenhnhan,
    dv.tendichvu,
    COALESCE(kq.ai_canhbaoruiro, 'Chưa có kết quả khám'::text) AS ai_suckhoe,
    COALESCE(dg.ai_phantichcamxuc, 'Chưa có đánh giá'::character varying) AS ai_camxuc,
        CASE
            WHEN (kq.ai_dotincay IS NULL) THEN 'Đang chờ dữ liệu'::text
            WHEN (kq.ai_dotincay < 0.9) THEN 'Cần Bác sĩ kiểm tra lại'::text
            ELSE 'AI Độ tin cậy cao'::text
        END AS ai_status
   FROM ((((public.lich_hen lh
     LEFT JOIN public.benh_nhan bn ON (((lh.mabenhnhan)::text = (bn.mabenhnhan)::text)))
     LEFT JOIN public.dich_vu dv ON (((lh.madichvu)::text = (dv.madichvu)::text)))
     LEFT JOIN public.ket_qua_kham kq ON (((lh.malichhen)::text = (kq.malichhen)::text)))
     LEFT JOIN public.danh_gia dg ON (((lh.malichhen)::text = (dg.malichhen)::text)));


--
-- TOC entry 230 (class 1259 OID 17271)
-- Name: vw_bacsiuytin; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_bacsiuytin AS
 SELECT manhanvien,
    hoten,
    sonamkinhnghiem,
    diemuytin,
    trangthai
   FROM public.nhan_vien_y_te
  WHERE (((loainhansu)::text = 'Bác sĩ'::text) AND (diemuytin >= 4.5))
  ORDER BY diemuytin DESC;


--
-- TOC entry 233 (class 1259 OID 17285)
-- Name: vw_canhbaovattu; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_canhbaovattu AS
 SELECT mavattu,
    tenvattu,
    soluongton,
    'Sắp hết hàng'::text AS tinhtrang
   FROM public.vat_tu_y_te
  WHERE (soluongton < 10);


--
-- TOC entry 231 (class 1259 OID 17275)
-- Name: vw_doanhthutheodichvu; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_doanhthutheodichvu AS
 SELECT dv.madichvu,
    dv.tendichvu,
    count(hd.mahoadon) AS soluotsudung,
    sum(hd.tongtiendichvu) AS doanhthudichvu,
    sum(hd.tongthanhtoan) AS tongdoanhthuthucte
   FROM ((public.dich_vu dv
     LEFT JOIN public.lich_hen lh ON (((dv.madichvu)::text = (lh.madichvu)::text)))
     LEFT JOIN public.hoa_don hd ON (((lh.malichhen)::text = (hd.malichhen)::text)))
  GROUP BY dv.madichvu, dv.tendichvu;


--
-- TOC entry 232 (class 1259 OID 17280)
-- Name: vw_lichsukhambenhnhan; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_lichsukhambenhnhan AS
 SELECT bn.mabenhnhan,
    bn.hoten AS tenbenhnhan,
    lh.thoigianbatdau,
    dv.tendichvu,
    nv.hoten AS bacsithuchien,
    kq.chandoansobo,
    kq.ylenh,
    hd.trangthaithanhtoan
   FROM (((((public.benh_nhan bn
     JOIN public.lich_hen lh ON (((bn.mabenhnhan)::text = (lh.mabenhnhan)::text)))
     JOIN public.dich_vu dv ON (((lh.madichvu)::text = (dv.madichvu)::text)))
     JOIN public.nhan_vien_y_te nv ON (((lh.manhanvien)::text = (nv.manhanvien)::text)))
     LEFT JOIN public.ket_qua_kham kq ON (((lh.malichhen)::text = (kq.malichhen)::text)))
     LEFT JOIN public.hoa_don hd ON (((lh.malichhen)::text = (hd.malichhen)::text)))
  ORDER BY lh.thoigianbatdau DESC;


--
-- TOC entry 4899 (class 2606 OID 17232)
-- Name: admin admin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin
    ADD CONSTRAINT admin_pkey PRIMARY KEY (maadmin);


--
-- TOC entry 4901 (class 2606 OID 17234)
-- Name: admin admin_tendangnhap_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin
    ADD CONSTRAINT admin_tendangnhap_key UNIQUE (tendangnhap);


--
-- TOC entry 4871 (class 2606 OID 17073)
-- Name: benh_nhan benh_nhan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.benh_nhan
    ADD CONSTRAINT benh_nhan_pkey PRIMARY KEY (mabenhnhan);


--
-- TOC entry 4889 (class 2606 OID 17180)
-- Name: chi_tiet_vat_tu chi_tiet_vat_tu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_vat_tu
    ADD CONSTRAINT chi_tiet_vat_tu_pkey PRIMARY KEY (maketqua, mavattu);


--
-- TOC entry 4879 (class 2606 OID 17101)
-- Name: chuyen_khoa chuyen_khoa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chuyen_khoa
    ADD CONSTRAINT chuyen_khoa_pkey PRIMARY KEY (machuyenkhoa);


--
-- TOC entry 4895 (class 2606 OID 17221)
-- Name: danh_gia danh_gia_malichhen_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danh_gia
    ADD CONSTRAINT danh_gia_malichhen_key UNIQUE (malichhen);


--
-- TOC entry 4897 (class 2606 OID 17219)
-- Name: danh_gia danh_gia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danh_gia
    ADD CONSTRAINT danh_gia_pkey PRIMARY KEY (madanhgia);


--
-- TOC entry 4883 (class 2606 OID 17126)
-- Name: dich_vu dich_vu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dich_vu
    ADD CONSTRAINT dich_vu_pkey PRIMARY KEY (madichvu);


--
-- TOC entry 4891 (class 2606 OID 17204)
-- Name: hoa_don hoa_don_malichhen_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_malichhen_key UNIQUE (malichhen);


--
-- TOC entry 4893 (class 2606 OID 17202)
-- Name: hoa_don hoa_don_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_pkey PRIMARY KEY (mahoadon);


--
-- TOC entry 4903 (class 2606 OID 17256)
-- Name: ket_qua_kham ket_qua_kham_malichhen_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ket_qua_kham
    ADD CONSTRAINT ket_qua_kham_malichhen_key UNIQUE (malichhen);


--
-- TOC entry 4905 (class 2606 OID 17254)
-- Name: ket_qua_kham ket_qua_kham_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ket_qua_kham
    ADD CONSTRAINT ket_qua_kham_pkey PRIMARY KEY (maketqua);


--
-- TOC entry 4865 (class 2606 OID 17064)
-- Name: khach_hang khach_hang_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_email_key UNIQUE (email);


--
-- TOC entry 4867 (class 2606 OID 17060)
-- Name: khach_hang khach_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_pkey PRIMARY KEY (makhachhang);


--
-- TOC entry 4869 (class 2606 OID 17062)
-- Name: khach_hang khach_hang_sodienthoai_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_sodienthoai_key UNIQUE (sodienthoai);


--
-- TOC entry 4885 (class 2606 OID 17134)
-- Name: lich_hen lich_hen_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_hen
    ADD CONSTRAINT lich_hen_pkey PRIMARY KEY (malichhen);


--
-- TOC entry 4881 (class 2606 OID 17106)
-- Name: nhan_vien_chuyen_khoa nhan_vien_chuyen_khoa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_chuyen_khoa
    ADD CONSTRAINT nhan_vien_chuyen_khoa_pkey PRIMARY KEY (manhanvien, machuyenkhoa);


--
-- TOC entry 4873 (class 2606 OID 17094)
-- Name: nhan_vien_y_te nhan_vien_y_te_cccd_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_y_te
    ADD CONSTRAINT nhan_vien_y_te_cccd_key UNIQUE (cccd);


--
-- TOC entry 4875 (class 2606 OID 17092)
-- Name: nhan_vien_y_te nhan_vien_y_te_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_y_te
    ADD CONSTRAINT nhan_vien_y_te_pkey PRIMARY KEY (manhanvien);


--
-- TOC entry 4877 (class 2606 OID 17096)
-- Name: nhan_vien_y_te nhan_vien_y_te_sodienthoai_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_y_te
    ADD CONSTRAINT nhan_vien_y_te_sodienthoai_key UNIQUE (sodienthoai);


--
-- TOC entry 4887 (class 2606 OID 17173)
-- Name: vat_tu_y_te vat_tu_y_te_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_tu_y_te
    ADD CONSTRAINT vat_tu_y_te_pkey PRIMARY KEY (mavattu);


--
-- TOC entry 4919 (class 2620 OID 25485)
-- Name: danh_gia trg_ai_phantichcamxuc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ai_phantichcamxuc BEFORE INSERT OR UPDATE ON public.danh_gia FOR EACH ROW EXECUTE FUNCTION public.fn_ai_phantichcamxuc();


--
-- TOC entry 4920 (class 2620 OID 25464)
-- Name: ket_qua_kham trg_ai_phantichsuckhoe; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ai_phantichsuckhoe BEFORE INSERT OR UPDATE ON public.ket_qua_kham FOR EACH ROW EXECUTE FUNCTION public.fn_ai_phantichsuckhoe();


--
-- TOC entry 4916 (class 2620 OID 17243)
-- Name: benh_nhan trg_gioihanhosobenhnhan; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_gioihanhosobenhnhan BEFORE INSERT ON public.benh_nhan FOR EACH ROW EXECUTE FUNCTION public.fn_gioihanhosobenhnhan();


--
-- TOC entry 4917 (class 2620 OID 17241)
-- Name: lich_hen trg_kiemtratrunglich; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kiemtratrunglich BEFORE INSERT OR UPDATE ON public.lich_hen FOR EACH ROW EXECUTE FUNCTION public.fn_kiemtratrunglich();


--
-- TOC entry 4918 (class 2620 OID 17245)
-- Name: chi_tiet_vat_tu trg_trutonkhovattu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_trutonkhovattu AFTER INSERT ON public.chi_tiet_vat_tu FOR EACH ROW EXECUTE FUNCTION public.fn_trutonkhovattu();


--
-- TOC entry 4912 (class 2606 OID 17186)
-- Name: chi_tiet_vat_tu chi_tiet_vat_tu_mavattu_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_vat_tu
    ADD CONSTRAINT chi_tiet_vat_tu_mavattu_fkey FOREIGN KEY (mavattu) REFERENCES public.vat_tu_y_te(mavattu);


--
-- TOC entry 4914 (class 2606 OID 17222)
-- Name: danh_gia danh_gia_malichhen_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danh_gia
    ADD CONSTRAINT danh_gia_malichhen_fkey FOREIGN KEY (malichhen) REFERENCES public.lich_hen(malichhen);


--
-- TOC entry 4906 (class 2606 OID 17074)
-- Name: benh_nhan fk_bn_khachhang; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.benh_nhan
    ADD CONSTRAINT fk_bn_khachhang FOREIGN KEY (makhachhang) REFERENCES public.khach_hang(makhachhang) ON DELETE CASCADE;


--
-- TOC entry 4909 (class 2606 OID 17135)
-- Name: lich_hen fk_lh_benhnhan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_hen
    ADD CONSTRAINT fk_lh_benhnhan FOREIGN KEY (mabenhnhan) REFERENCES public.benh_nhan(mabenhnhan) ON DELETE RESTRICT;


--
-- TOC entry 4910 (class 2606 OID 17140)
-- Name: lich_hen fk_lh_dichvu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_hen
    ADD CONSTRAINT fk_lh_dichvu FOREIGN KEY (madichvu) REFERENCES public.dich_vu(madichvu);


--
-- TOC entry 4911 (class 2606 OID 17145)
-- Name: lich_hen fk_lh_nhanvien; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_hen
    ADD CONSTRAINT fk_lh_nhanvien FOREIGN KEY (manhanvien) REFERENCES public.nhan_vien_y_te(manhanvien);


--
-- TOC entry 4913 (class 2606 OID 17205)
-- Name: hoa_don hoa_don_malichhen_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_malichhen_fkey FOREIGN KEY (malichhen) REFERENCES public.lich_hen(malichhen);


--
-- TOC entry 4915 (class 2606 OID 17257)
-- Name: ket_qua_kham ket_qua_kham_malichhen_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ket_qua_kham
    ADD CONSTRAINT ket_qua_kham_malichhen_fkey FOREIGN KEY (malichhen) REFERENCES public.lich_hen(malichhen) ON DELETE CASCADE;


--
-- TOC entry 4907 (class 2606 OID 17112)
-- Name: nhan_vien_chuyen_khoa nhan_vien_chuyen_khoa_machuyenkhoa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_chuyen_khoa
    ADD CONSTRAINT nhan_vien_chuyen_khoa_machuyenkhoa_fkey FOREIGN KEY (machuyenkhoa) REFERENCES public.chuyen_khoa(machuyenkhoa) ON DELETE CASCADE;


--
-- TOC entry 4908 (class 2606 OID 17107)
-- Name: nhan_vien_chuyen_khoa nhan_vien_chuyen_khoa_manhanvien_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_chuyen_khoa
    ADD CONSTRAINT nhan_vien_chuyen_khoa_manhanvien_fkey FOREIGN KEY (manhanvien) REFERENCES public.nhan_vien_y_te(manhanvien) ON DELETE CASCADE;


-- Completed on 2026-05-16 17:43:28

--
-- PostgreSQL database dump complete
--

\unrestrict Dym2swXWitmRtnCnI5YkQMsJvRo9SIhlE0uOnZWQTZuPabR66Gxtxq6gdp7foyw

