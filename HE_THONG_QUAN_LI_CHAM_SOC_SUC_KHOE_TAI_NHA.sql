--
-- PostgreSQL database dump
--

\restrict Y5D1Pqy2aeljrDpQ7V4HLUJSQY8ivEbv6Q0J4KH5CFOq2VkuQItLiSCICuS1835

-- Dumped from database version 17.9
-- Dumped by pg_dump version 17.9

-- Started on 2026-05-17 16:08:27

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
-- TOC entry 254 (class 1255 OID 17266)
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
-- TOC entry 249 (class 1255 OID 17263)
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
-- TOC entry 257 (class 1255 OID 17269)
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
-- TOC entry 255 (class 1255 OID 17267)
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
-- TOC entry 258 (class 1255 OID 17270)
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
-- TOC entry 256 (class 1255 OID 17268)
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
-- TOC entry 248 (class 1255 OID 17262)
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
-- TOC entry 251 (class 1255 OID 25493)
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
-- TOC entry 259 (class 1255 OID 17239)
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
-- TOC entry 260 (class 1255 OID 25465)
-- Name: trg_ai_phantichcamxuc(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_ai_phantichcamxuc() RETURNS trigger
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
-- Name: trg_ai_phantichsuckhoe(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_ai_phantichsuckhoe() RETURNS trigger
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
-- TOC entry 261 (class 1255 OID 17235)
-- Name: trg_canhcaonhanvienhuylich(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_canhcaonhanvienhuylich() RETURNS trigger
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
-- TOC entry 252 (class 1255 OID 17242)
-- Name: trg_gioihanhosobenhnhan(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_gioihanhosobenhnhan() RETURNS trigger
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
-- TOC entry 262 (class 1255 OID 17236)
-- Name: trg_khoaketquakham(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_khoaketquakham() RETURNS trigger
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
-- TOC entry 263 (class 1255 OID 17237)
-- Name: trg_kiemtrahosinhkhoasan(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_kiemtrahosinhkhoasan() RETURNS trigger
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
-- TOC entry 264 (class 1255 OID 17238)
-- Name: trg_kiemtraluongtrangthai(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_kiemtraluongtrangthai() RETURNS trigger
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
-- TOC entry 250 (class 1255 OID 17240)
-- Name: trg_kiemtratrunglich(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_kiemtratrunglich() RETURNS trigger
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
-- TOC entry 253 (class 1255 OID 17244)
-- Name: trg_trutonkhovattu(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_trutonkhovattu() RETURNS trigger
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


SET default_tablespace = '';

SET default_table_access_method = heap;

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
-- TOC entry 5083 (class 0 OID 17227)
-- Dependencies: 228
-- Data for Name: admin; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.admin VALUES ('AD001', 'system_3668', 'Fy$43771', 'Đỗ Thị Huy', 'Super Admin');
INSERT INTO public.admin VALUES ('AD002', 'quanly_2833', 'Be$10011', 'Hồ Phương Anh', 'Quản lý Y tế');
INSERT INTO public.admin VALUES ('AD003', 'mod_7733', 'Ef#54069', 'Nguyễn Thị Anh', 'Quản lý Nhân sự');
INSERT INTO public.admin VALUES ('AD004', 'quanly_4696', 'Hx&62387', 'Bùi Ngọc Đức', 'Kế toán');
INSERT INTO public.admin VALUES ('AD005', 'admin_7946', 'Ec&51517', 'Đặng Bảo Linh', 'Chăm sóc Khách hàng');
INSERT INTO public.admin VALUES ('AD006', 'cskh_3147', 'Bz*64621', 'Đặng Gia Yến', 'Quản lý Kỹ thuật');


--
-- TOC entry 5073 (class 0 OID 17065)
-- Dependencies: 218
-- Data for Name: benh_nhan; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.benh_nhan VALUES ('BN001', 'KH001', 'Đặng Thị Hương', '2007-01-28', 'Nữ', 'A', 'Số 112, Đường Trần Hưng Đạo, Quận 7, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN002', 'KH002', 'Vũ Ngọc Em', '1969-09-01', 'Nam', 'B', 'Số 1, Đường Trần Hưng Đạo, Quận 1, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN003', 'KH003', 'Bùi Thanh Dũng', '1966-06-28', 'Nam', 'AB', 'Số 303, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN004', 'KH004', 'Lê Văn Thảo', '1981-08-22', 'Nữ', 'O', 'Số 945, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN005', 'KH005', 'Đặng Anh An', '2002-05-27', 'Nữ', 'A', 'Số 938, Đường Cách Mạng Tháng 8, Quận 7, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN006', 'KH006', 'Hoàng Thanh Thảo', '1972-02-14', 'Nữ', 'A', 'Số 767, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN007', 'KH007', 'Trần Thanh Chi', '1961-10-14', 'Nữ', 'O', 'Số 339, Đường Trần Hưng Đạo, Quận 10, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN008', 'KH008', 'Hoàng Anh Quân', '1965-05-19', 'Nữ', 'O', 'Số 303, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Tăng huyết áp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN009', 'KH009', 'Đỗ Anh Nam', '1980-12-02', 'Nữ', 'B', 'Số 147, Đường Cách Mạng Tháng 8, Quận 10, TP. Hồ Chí Minh', 'Dị ứng thuốc', NULL);
INSERT INTO public.benh_nhan VALUES ('BN010', 'KH010', 'Phan Khánh Chi', '2010-12-07', 'Nam', 'A', 'Số 186, Đường Điện Biên Phủ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN011', 'KH011', 'Phạm Thanh Nam', '2008-04-13', 'Nam', 'AB', 'Số 687, Đường Điện Biên Phủ, Quận 7, TP. Hồ Chí Minh', 'Ung thư vú', NULL);
INSERT INTO public.benh_nhan VALUES ('BN012', 'KH012', 'Đặng Gia An', '1980-12-27', 'Nam', 'B', 'Số 669, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN013', 'KH013', 'Đặng Khánh Em', '1988-01-05', 'Nam', 'A', 'Số 49, Đường Lê Lợi, Tân Bình, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN014', 'KH014', 'Vũ Minh Bình', '2011-03-03', 'Nữ', 'O', 'Số 347, Đường Cách Mạng Tháng 8, Quận 5, TP. Hồ Chí Minh', 'Mất ngủ kéo dài', NULL);
INSERT INTO public.benh_nhan VALUES ('BN015', 'KH015', 'Vũ Minh Quân', '1961-05-06', 'Nam', 'O', 'Số 623, Đường Điện Biên Phủ, Tân Bình, TP. Hồ Chí Minh', 'Viêm gan B', NULL);
INSERT INTO public.benh_nhan VALUES ('BN016', 'KH016', 'Vũ Ngọc Hương', '1978-07-26', 'Nữ', 'AB', 'Số 235, Đường Phan Xích Long, Quận 10, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN017', 'KH017', 'Phạm Thị Tuấn', '1979-03-24', 'Nữ', 'B', 'Số 821, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Rối loạn mỡ máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN018', 'KH018', 'Vũ Thị Tuấn', '1963-09-07', 'Nữ', 'O', 'Số 581, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN019', 'KH019', 'Đặng Ngọc Thảo', '2010-01-11', 'Nam', 'O', 'Số 746, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'Suy tim', NULL);
INSERT INTO public.benh_nhan VALUES ('BN020', 'KH020', 'Đặng Gia Dũng', '2002-02-23', 'Nam', 'O', 'Số 650, Đường Điện Biên Phủ, Quận 1, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN021', 'KH021', 'Phan Thanh Chi', '1972-10-30', 'Nam', 'B', 'Số 721, Đường Cách Mạng Tháng 8, Gò Vấp, TP. Hồ Chí Minh', 'Ung thư gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN022', 'KH022', 'Phan Thị Thảo', '2013-05-07', 'Nữ', 'A', 'Số 969, Đường Cách Mạng Tháng 8, Quận 5, TP. Hồ Chí Minh', 'Ung thư vú', NULL);
INSERT INTO public.benh_nhan VALUES ('BN023', 'KH023', 'Đỗ Minh Quân', '2025-03-22', 'Nam', 'B', 'Số 218, Đường Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN024', 'KH024', 'Trần Gia Quân', '2011-05-26', 'Nữ', 'A', 'Số 317, Đường Phan Xích Long, Quận 7, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN025', 'KH025', 'Hoàng Gia Linh', '2004-07-03', 'Nam', 'O', 'Số 882, Đường Phan Xích Long, Quận 5, TP. Hồ Chí Minh', 'Viêm gan B', NULL);
INSERT INTO public.benh_nhan VALUES ('BN026', 'KH026', 'Bùi Anh Khôi', '2014-03-31', 'Nam', 'A', 'Số 605, Đường Cách Mạng Tháng 8, Quận 7, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN027', 'KH027', 'Nguyễn Gia Nam', '1986-10-22', 'Nữ', 'A', 'Số 739, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN028', 'KH028', 'Phạm Khánh Tuấn', '1970-12-02', 'Nam', 'B', 'Số 367, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN029', 'KH029', 'Lê Khánh Quân', '1961-06-03', 'Nữ', 'B', 'Số 150, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN030', 'KH030', 'Hoàng Hoàng Chi', '2000-03-12', 'Nữ', 'B', 'Số 178, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN031', 'KH031', 'Vũ Ngọc Linh', '1963-06-16', 'Nam', 'AB', 'Số 523, Đường Điện Biên Phủ, Quận 3, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN032', 'KH032', 'Đỗ Ngọc Dũng', '1994-06-25', 'Nam', 'AB', 'Số 776, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Rối loạn mỡ máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN033', 'KH033', 'Nguyễn Thị Linh', '2000-05-14', 'Nam', 'A', 'Số 191, Đường Trần Hưng Đạo, Tân Bình, TP. Hồ Chí Minh', 'Viêm gan B', NULL);
INSERT INTO public.benh_nhan VALUES ('BN034', 'KH034', 'Nguyễn Minh An', '1974-03-05', 'Nữ', 'AB', 'Số 461, Đường Điện Biên Phủ, Quận 5, TP. Hồ Chí Minh', 'Dị ứng thực phẩm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN035', 'KH035', 'Bùi Minh An', '1990-09-13', 'Nữ', 'A', 'Số 314, Đường Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN036', 'KH036', 'Trần Anh Khôi', '2024-11-13', 'Nam', 'AB', 'Số 978, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hen suyễn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN037', 'KH037', 'Phạm Khánh Tuấn', '2013-08-22', 'Nam', 'O', 'Số 86, Đường Điện Biên Phủ, Quận 1, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN038', 'KH038', 'Phạm Ngọc Chi', '2024-12-28', 'Nữ', 'O', 'Số 279, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN039', 'KH039', 'Trần Hoàng Nam', '2008-11-07', 'Nữ', 'AB', 'Số 168, Đường Trần Hưng Đạo, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN040', 'KH040', 'Phạm Thanh Dũng', '1963-06-06', 'Nữ', 'A', 'Số 752, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN041', 'KH041', 'Trần Gia Tuấn', '1994-11-14', 'Nữ', 'A', 'Số 944, Đường Lê Lợi, Gò Vấp, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN042', 'KH042', 'Đặng Anh Linh', '1996-12-06', 'Nam', 'O', 'Số 68, Đường Lê Lợi, Gò Vấp, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN043', 'KH043', 'Trần Anh Thảo', '1986-05-19', 'Nam', 'A', 'Số 679, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN044', 'KH044', 'Vũ Ngọc Quân', '1974-12-14', 'Nam', 'AB', 'Số 713, Đường Cách Mạng Tháng 8, Quận 5, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN045', 'KH045', 'Trần Khánh Chi', '1987-11-05', 'Nam', 'B', 'Số 668, Đường Phan Xích Long, Quận 10, TP. Hồ Chí Minh', 'Suy tim', NULL);
INSERT INTO public.benh_nhan VALUES ('BN046', 'KH046', 'Đặng Hoàng Em', '1963-10-04', 'Nam', 'B', 'Số 6, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN047', 'KH047', 'Trần Hoàng Em', '2018-01-21', 'Nam', 'AB', 'Số 291, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN048', 'KH048', 'Phan Thanh Chi', '1988-10-17', 'Nữ', 'A', 'Số 186, Đường Phan Xích Long, Quận 10, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN049', 'KH049', 'Trần Anh Chi', '2022-01-05', 'Nữ', 'A', 'Số 561, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN050', 'KH050', 'Đặng Văn Chi', '2023-03-26', 'Nam', 'A', 'Số 268, Đường Cách Mạng Tháng 8, Quận 5, TP. Hồ Chí Minh', 'Hen suyễn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN051', 'KH051', 'Nguyễn Minh Khôi', '1983-06-24', 'Nữ', 'A', 'Số 114, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN052', 'KH052', 'Vũ Thanh Dũng', '1961-08-29', 'Nam', 'O', 'Số 335, Đường Trần Hưng Đạo, Quận 3, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN053', 'KH053', 'Phạm Văn Nam', '2008-11-30', 'Nam', 'AB', 'Số 19, Đường Điện Biên Phủ, Tân Bình, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN054', 'KH054', 'Bùi Thanh An', '1994-06-10', 'Nam', 'A', 'Số 791, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN055', 'KH055', 'Hoàng Khánh Tuấn', '1989-09-23', 'Nữ', 'A', 'Số 523, Đường Cách Mạng Tháng 8, Quận 5, TP. Hồ Chí Minh', 'Rối loạn lo âu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN056', 'KH056', 'Đặng Anh Bình', '2004-12-24', 'Nữ', 'O', 'Số 841, Đường Điện Biên Phủ, Tân Bình, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN057', 'KH057', 'Đặng Ngọc Tuấn', '2022-12-19', 'Nữ', 'B', 'Số 202, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN058', 'KH058', 'Lê Văn Khôi', '2023-07-06', 'Nữ', 'B', 'Số 592, Đường Trần Hưng Đạo, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN059', 'KH059', 'Đặng Anh Tuấn', '1976-08-03', 'Nam', 'O', 'Số 169, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN060', 'KH060', 'Đỗ Hoàng Linh', '1994-08-13', 'Nam', 'O', 'Số 766, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN061', 'KH061', 'Lê Ngọc Hương', '1961-12-28', 'Nữ', 'A', 'Số 963, Đường Cách Mạng Tháng 8, Gò Vấp, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN062', 'KH062', 'Trần Gia Hương', '1982-02-03', 'Nam', 'AB', 'Số 200, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Dị ứng thuốc', NULL);
INSERT INTO public.benh_nhan VALUES ('BN063', 'KH063', 'Đặng Thanh Thảo', '2019-01-03', 'Nữ', 'B', 'Số 973, Đường Trần Hưng Đạo, Quận 1, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN064', 'KH064', 'Trần Hoàng Tuấn', '1970-12-13', 'Nữ', 'A', 'Số 636, Đường Điện Biên Phủ, Quận 1, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN065', 'KH065', 'Hoàng Văn Chi', '2022-05-13', 'Nam', 'A', 'Số 246, Đường Cách Mạng Tháng 8, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN066', 'KH066', 'Nguyễn Thanh An', '2026-03-08', 'Nữ', 'B', 'Số 423, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN067', 'KH067', 'Hoàng Gia Dũng', '2021-12-06', 'Nữ', 'B', 'Số 23, Đường Phan Xích Long, Quận 7, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN068', 'KH068', 'Nguyễn Hoàng Em', '1977-08-13', 'Nữ', 'A', 'Số 600, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN069', 'KH069', 'Bùi Ngọc An', '2006-12-24', 'Nam', 'AB', 'Số 306, Đường Trần Hưng Đạo, Quận 1, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN070', 'KH070', 'Trần Văn Hương', '2014-01-16', 'Nữ', 'A', 'Số 80, Đường Cách Mạng Tháng 8, Quận 7, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN071', 'KH071', 'Đỗ Ngọc Nam', '1986-08-20', 'Nam', 'A', 'Số 223, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN072', 'KH072', 'Phan Hoàng Chi', '1991-11-22', 'Nam', 'O', 'Số 913, Đường Điện Biên Phủ, Quận 7, TP. Hồ Chí Minh', 'Viêm gan B', NULL);
INSERT INTO public.benh_nhan VALUES ('BN073', 'KH073', 'Bùi Minh Linh', '1984-10-27', 'Nam', 'O', 'Số 459, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Rối loạn lo âu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN074', 'KH074', 'Hoàng Thanh An', '1982-06-20', 'Nam', 'O', 'Số 75, Đường Điện Biên Phủ, Gò Vấp, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN075', 'KH075', 'Hoàng Ngọc Thảo', '2025-11-08', 'Nam', 'A', 'Số 10, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Rối loạn mỡ máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN076', 'KH076', 'Phan Hoàng Khôi', '1999-05-14', 'Nam', 'AB', 'Số 322, Đường Phan Xích Long, Gò Vấp, TP. Hồ Chí Minh', 'Ung thư gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN077', 'KH077', 'Trần Hoàng Em', '1963-10-28', 'Nam', 'O', 'Số 85, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Ung thư gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN078', 'KH078', 'Lê Thanh Em', '1986-09-28', 'Nam', 'B', 'Số 466, Đường Cách Mạng Tháng 8, Gò Vấp, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN079', 'KH079', 'Phạm Gia Tuấn', '2021-06-26', 'Nữ', 'AB', 'Số 21, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN080', 'KH080', 'Trần Gia Tuấn', '1988-03-30', 'Nữ', 'B', 'Số 517, Đường Điện Biên Phủ, Gò Vấp, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN081', 'KH081', 'Phạm Khánh Hương', '2016-09-10', 'Nữ', 'B', 'Số 425, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN082', 'KH082', 'Phạm Gia Em', '2022-12-18', 'Nữ', 'O', 'Số 379, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN083', 'KH083', 'Lê Anh Linh', '1985-10-25', 'Nam', 'B', 'Số 358, Đường Trần Hưng Đạo, Quận 3, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN084', 'KH084', 'Bùi Gia Em', '1981-10-05', 'Nữ', 'AB', 'Số 237, Đường Cách Mạng Tháng 8, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Suy tim', NULL);
INSERT INTO public.benh_nhan VALUES ('BN085', 'KH085', 'Đặng Minh An', '1971-03-06', 'Nữ', 'AB', 'Số 573, Đường Trần Hưng Đạo, Quận 7, TP. Hồ Chí Minh', 'Rối loạn mỡ máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN086', 'KH086', 'Bùi Văn Thảo', '2011-10-28', 'Nam', 'O', 'Số 210, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN087', 'KH087', 'Đặng Khánh Em', '1985-03-26', 'Nam', 'O', 'Số 994, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN088', 'KH088', 'Bùi Khánh Bình', '1986-10-02', 'Nam', 'O', 'Số 197, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN089', 'KH089', 'Hoàng Ngọc Thảo', '1975-12-15', 'Nữ', 'O', 'Số 880, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN090', 'KH090', 'Vũ Minh Thảo', '2024-07-24', 'Nam', 'B', 'Số 257, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN091', 'KH091', 'Nguyễn Khánh Tuấn', '1981-03-22', 'Nam', 'A', 'Số 119, Đường Điện Biên Phủ, Quận 10, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN092', 'KH092', 'Trần Hoàng Bình', '1974-04-15', 'Nữ', 'A', 'Số 362, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Rối loạn mỡ máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN093', 'KH093', 'Phan Thị Em', '1991-04-11', 'Nam', 'AB', 'Số 41, Đường Điện Biên Phủ, Quận 10, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN094', 'KH094', 'Phan Anh Chi', '2004-05-27', 'Nữ', 'B', 'Số 319, Đường Phan Xích Long, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN095', 'KH095', 'Nguyễn Văn Linh', '2013-12-05', 'Nữ', 'AB', 'Số 291, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN096', 'KH096', 'Vũ Gia Tuấn', '1983-12-02', 'Nữ', 'O', 'Số 930, Đường Điện Biên Phủ, Quận 5, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN097', 'KH097', 'Vũ Văn Thảo', '1998-01-04', 'Nữ', 'AB', 'Số 846, Đường Cách Mạng Tháng 8, Quận 1, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN098', 'KH098', 'Trần Khánh Quân', '1979-06-18', 'Nam', 'O', 'Số 379, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN099', 'KH099', 'Hoàng Ngọc Chi', '1990-09-25', 'Nữ', 'A', 'Số 391, Đường Phan Xích Long, Gò Vấp, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN100', 'KH100', 'Phan Văn Nam', '2000-10-04', 'Nữ', 'O', 'Số 931, Đường Phan Xích Long, Gò Vấp, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN101', 'KH101', 'Phan Thanh Chi', '2014-08-05', 'Nam', 'A', 'Số 782, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN102', 'KH102', 'Đặng Minh Bình', '2001-03-24', 'Nữ', 'A', 'Số 564, Đường Cách Mạng Tháng 8, Tân Bình, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN103', 'KH103', 'Phan Hoàng Hương', '1979-03-30', 'Nam', 'AB', 'Số 508, Đường Phan Xích Long, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN104', 'KH104', 'Bùi Khánh Em', '1960-01-20', 'Nam', 'AB', 'Số 683, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Viêm gan B', NULL);
INSERT INTO public.benh_nhan VALUES ('BN105', 'KH105', 'Trần Ngọc Em', '2008-04-30', 'Nam', 'AB', 'Số 449, Đường Phan Xích Long, Quận 5, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN106', 'KH106', 'Lê Ngọc Hương', '2014-08-18', 'Nữ', 'B', 'Số 698, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN107', 'KH107', 'Lê Anh Khôi', '1969-05-27', 'Nam', 'B', 'Số 239, Đường Nguyễn Huệ, Tân Bình, TP. Hồ Chí Minh', 'Viêm gan B', NULL);
INSERT INTO public.benh_nhan VALUES ('BN108', 'KH108', 'Vũ Ngọc Linh', '2012-06-06', 'Nữ', 'B', 'Số 40, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Ung thư vú', NULL);
INSERT INTO public.benh_nhan VALUES ('BN109', 'KH109', 'Đỗ Hoàng Em', '1979-06-14', 'Nữ', 'O', 'Số 965, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Mất ngủ kéo dài', NULL);
INSERT INTO public.benh_nhan VALUES ('BN110', 'KH110', 'Lê Hoàng Hương', '1999-06-28', 'Nữ', 'O', 'Số 539, Đường Trần Hưng Đạo, Tân Bình, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN111', 'KH111', 'Bùi Khánh Chi', '1999-04-13', 'Nam', 'O', 'Số 35, Đường Điện Biên Phủ, Quận 3, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN112', 'KH112', 'Vũ Minh Bình', '1988-09-24', 'Nữ', 'O', 'Số 204, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN113', 'KH113', 'Vũ Thanh Hương', '1989-01-29', 'Nam', 'AB', 'Số 325, Đường Cách Mạng Tháng 8, Quận 1, TP. Hồ Chí Minh', 'Dị ứng thuốc', NULL);
INSERT INTO public.benh_nhan VALUES ('BN114', 'KH114', 'Đỗ Ngọc Nam', '2003-05-10', 'Nữ', 'O', 'Số 262, Đường Trần Hưng Đạo, Tân Bình, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN115', 'KH115', 'Trần Văn An', '2017-08-25', 'Nam', 'O', 'Số 314, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Tăng huyết áp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN116', 'KH116', 'Phan Hoàng Dũng', '2010-05-22', 'Nam', 'B', 'Số 631, Đường Phan Xích Long, Quận 5, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN117', 'KH117', 'Vũ Văn Nam', '1987-05-13', 'Nữ', 'AB', 'Số 298, Đường Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN118', 'KH118', 'Nguyễn Gia Chi', '1974-01-03', 'Nữ', 'B', 'Số 25, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN119', 'KH119', 'Đỗ Hoàng Quân', '1986-04-05', 'Nam', 'B', 'Số 201, Đường Trần Hưng Đạo, Quận 5, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN120', 'KH120', 'Lê Hoàng Dũng', '1963-03-26', 'Nam', 'A', 'Số 999, Đường Phan Xích Long, Gò Vấp, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN121', 'KH121', 'Phạm Thanh Bình', '2012-05-25', 'Nam', 'AB', 'Số 700, Đường Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN122', 'KH122', 'Phan Hoàng An', '1964-08-31', 'Nam', 'O', 'Số 22, Đường Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN123', 'KH123', 'Đặng Anh An', '1966-10-15', 'Nam', 'A', 'Số 365, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN124', 'KH124', 'Nguyễn Anh Hương', '2008-05-09', 'Nam', 'AB', 'Số 780, Đường Phan Xích Long, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN125', 'KH125', 'Đỗ Văn Em', '1977-11-19', 'Nữ', 'O', 'Số 905, Đường Lê Lợi, Gò Vấp, TP. Hồ Chí Minh', 'Hen suyễn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN126', 'KH126', 'Bùi Khánh Khôi', '1996-02-05', 'Nam', 'O', 'Số 879, Đường Phan Xích Long, Quận 10, TP. Hồ Chí Minh', 'Mất ngủ kéo dài', NULL);
INSERT INTO public.benh_nhan VALUES ('BN127', 'KH127', 'Phan Anh Chi', '2025-07-25', 'Nam', 'B', 'Số 558, Đường Trần Hưng Đạo, Tân Bình, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN128', 'KH128', 'Phan Minh Hương', '2022-05-14', 'Nam', 'A', 'Số 895, Đường Điện Biên Phủ, Quận 7, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN129', 'KH129', 'Nguyễn Gia An', '2006-09-19', 'Nam', 'AB', 'Số 375, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Rối loạn lo âu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN130', 'KH130', 'Lê Minh Chi', '2016-10-07', 'Nữ', 'B', 'Số 154, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'Mất ngủ kéo dài', NULL);
INSERT INTO public.benh_nhan VALUES ('BN131', 'KH131', 'Phan Khánh Nam', '2010-11-24', 'Nữ', 'B', 'Số 343, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN132', 'KH132', 'Phan Minh Khôi', '1960-10-02', 'Nam', 'O', 'Số 282, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN133', 'KH133', 'Đặng Khánh An', '1974-11-04', 'Nữ', 'AB', 'Số 402, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN134', 'KH134', 'Phan Khánh Hương', '2007-07-11', 'Nữ', 'AB', 'Số 302, Đường Điện Biên Phủ, Quận 1, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN135', 'KH135', 'Phan Thanh An', '1974-07-13', 'Nam', 'A', 'Số 475, Đường Phan Xích Long, Quận 5, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN136', 'KH136', 'Trần Gia Linh', '1965-08-16', 'Nữ', 'A', 'Số 984, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN137', 'KH137', 'Phạm Anh Dũng', '2004-02-03', 'Nữ', 'AB', 'Số 55, Đường Lê Lợi, Tân Bình, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN138', 'KH138', 'Trần Anh Quân', '2002-03-20', 'Nữ', 'O', 'Số 323, Đường Điện Biên Phủ, Quận 5, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN139', 'KH139', 'Hoàng Thị An', '1964-03-28', 'Nữ', 'A', 'Số 137, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN140', 'KH140', 'Bùi Khánh Thảo', '2005-07-16', 'Nam', 'AB', 'Số 78, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN141', 'KH141', 'Hoàng Thị Thảo', '2008-03-17', 'Nữ', 'B', 'Số 83, Đường Cách Mạng Tháng 8, Quận 1, TP. Hồ Chí Minh', 'Dị ứng thực phẩm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN142', 'KH142', 'Hoàng Thanh Quân', '1971-07-30', 'Nữ', 'AB', 'Số 566, Đường Phan Xích Long, Quận 7, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN143', 'KH143', 'Nguyễn Hoàng Linh', '1969-02-13', 'Nữ', 'AB', 'Số 162, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Suy tim', NULL);
INSERT INTO public.benh_nhan VALUES ('BN144', 'KH144', 'Hoàng Anh Tuấn', '1983-11-11', 'Nữ', 'O', 'Số 219, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN145', 'KH145', 'Nguyễn Thanh Dũng', '2012-07-27', 'Nam', 'AB', 'Số 426, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN146', 'KH146', 'Đặng Thanh Chi', '2003-01-01', 'Nam', 'AB', 'Số 572, Đường Cách Mạng Tháng 8, Gò Vấp, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN147', 'KH147', 'Vũ Văn Dũng', '1977-09-16', 'Nam', 'A', 'Số 814, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN148', 'KH148', 'Trần Khánh Linh', '2020-10-11', 'Nam', 'A', 'Số 471, Đường Điện Biên Phủ, Quận 5, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN149', 'KH149', 'Vũ Ngọc Nam', '1971-02-17', 'Nữ', 'O', 'Số 74, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN150', 'KH150', 'Phạm Văn Chi', '1977-05-26', 'Nữ', 'A', 'Số 72, Đường Cách Mạng Tháng 8, Quận 10, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN151', 'KH151', 'Đặng Văn Dũng', '2017-11-15', 'Nam', 'AB', 'Số 569, Đường Phan Xích Long, Quận 7, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN152', 'KH152', 'Đặng Văn Hương', '2003-06-25', 'Nam', 'B', 'Số 305, Đường Trần Hưng Đạo, Quận 10, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN153', 'KH153', 'Hoàng Anh Dũng', '1982-06-04', 'Nữ', 'AB', 'Số 853, Đường Phan Xích Long, Quận 5, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN154', 'KH154', 'Phan Thị Khôi', '2013-02-23', 'Nam', 'AB', 'Số 452, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN155', 'KH155', 'Nguyễn Gia Dũng', '2005-05-22', 'Nữ', 'AB', 'Số 552, Đường Cách Mạng Tháng 8, Gò Vấp, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN156', 'KH156', 'Vũ Ngọc Linh', '1990-07-13', 'Nam', 'AB', 'Số 255, Đường Điện Biên Phủ, Quận 10, TP. Hồ Chí Minh', 'Dị ứng thực phẩm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN157', 'KH157', 'Đỗ Minh An', '2012-04-11', 'Nam', 'AB', 'Số 31, Đường Điện Biên Phủ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN158', 'KH158', 'Lê Hoàng Tuấn', '1997-03-10', 'Nam', 'B', 'Số 397, Đường Nguyễn Huệ, Gò Vấp, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN159', 'KH159', 'Đặng Văn Linh', '1975-08-04', 'Nữ', 'A', 'Số 938, Đường Trần Hưng Đạo, Quận 7, TP. Hồ Chí Minh', 'Hen suyễn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN160', 'KH160', 'Vũ Khánh Khôi', '1977-10-10', 'Nam', 'B', 'Số 609, Đường Phan Xích Long, Quận 5, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN161', 'KH161', 'Bùi Thanh Khôi', '1967-06-02', 'Nam', 'B', 'Số 736, Đường Điện Biên Phủ, Gò Vấp, TP. Hồ Chí Minh', 'Dị ứng thực phẩm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN162', 'KH162', 'Lê Khánh Bình', '1976-01-28', 'Nam', 'A', 'Số 529, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN163', 'KH163', 'Đỗ Gia Quân', '1973-11-13', 'Nam', 'B', 'Số 25, Đường Điện Biên Phủ, Quận 10, TP. Hồ Chí Minh', 'Hen suyễn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN164', 'KH164', 'Đỗ Khánh Nam', '1974-06-12', 'Nam', 'B', 'Số 415, Đường Cách Mạng Tháng 8, Gò Vấp, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN165', 'KH165', 'Đỗ Anh Em', '1977-05-21', 'Nữ', 'B', 'Số 817, Đường Điện Biên Phủ, Tân Bình, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN166', 'KH166', 'Trần Thanh Dũng', '2009-09-15', 'Nam', 'A', 'Số 117, Đường Điện Biên Phủ, Quận 5, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN167', 'KH167', 'Phạm Khánh Em', '1962-04-13', 'Nam', 'AB', 'Số 534, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN168', 'KH168', 'Lê Ngọc Khôi', '2019-01-21', 'Nam', 'AB', 'Số 375, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN169', 'KH169', 'Nguyễn Thanh Quân', '1992-10-16', 'Nữ', 'AB', 'Số 313, Đường Điện Biên Phủ, Gò Vấp, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN170', 'KH170', 'Lê Minh Quân', '1964-06-24', 'Nữ', 'A', 'Số 595, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN171', 'KH171', 'Lê Hoàng Chi', '1963-03-18', 'Nữ', 'AB', 'Số 120, Đường Trần Hưng Đạo, Quận 3, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN172', 'KH172', 'Phạm Minh Thảo', '2002-04-14', 'Nữ', 'O', 'Số 929, Đường Phan Xích Long, Quận 10, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN173', 'KH173', 'Đặng Anh Nam', '1972-12-09', 'Nữ', 'B', 'Số 602, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN174', 'KH174', 'Bùi Khánh Khôi', '1960-11-17', 'Nam', 'O', 'Số 258, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN175', 'KH175', 'Bùi Minh Dũng', '1965-02-13', 'Nữ', 'O', 'Số 572, Đường Cách Mạng Tháng 8, Tân Bình, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN176', 'KH176', 'Nguyễn Minh An', '2000-09-12', 'Nữ', 'B', 'Số 427, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN177', 'KH177', 'Hoàng Thanh Dũng', '2008-08-18', 'Nam', 'AB', 'Số 538, Đường Trần Hưng Đạo, Quận 5, TP. Hồ Chí Minh', 'Mất ngủ kéo dài', NULL);
INSERT INTO public.benh_nhan VALUES ('BN178', 'KH178', 'Đỗ Văn Nam', '2010-10-11', 'Nữ', 'A', 'Số 218, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN179', 'KH179', 'Phan Ngọc Nam', '1973-09-11', 'Nam', 'O', 'Số 705, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN180', 'KH180', 'Lê Ngọc Quân', '2020-09-13', 'Nữ', 'O', 'Số 798, Đường Cách Mạng Tháng 8, Quận 10, TP. Hồ Chí Minh', 'Suy tim', NULL);
INSERT INTO public.benh_nhan VALUES ('BN181', 'KH181', 'Trần Văn Tuấn', '1996-12-13', 'Nam', 'AB', 'Số 496, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN182', 'KH182', 'Phan Ngọc Hương', '1971-09-16', 'Nam', 'AB', 'Số 584, Đường Trần Hưng Đạo, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Dị ứng thuốc', NULL);
INSERT INTO public.benh_nhan VALUES ('BN183', 'KH183', 'Phạm Minh Bình', '1985-12-12', 'Nữ', 'O', 'Số 253, Đường Cách Mạng Tháng 8, Quận 10, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN184', 'KH184', 'Đỗ Thị Chi', '1991-06-06', 'Nữ', 'A', 'Số 613, Đường Lê Lợi, Tân Bình, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN185', 'KH185', 'Đặng Thanh Linh', '2024-05-24', 'Nam', 'B', 'Số 927, Đường Trần Hưng Đạo, Quận 7, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN186', 'KH186', 'Phạm Anh Quân', '1979-12-21', 'Nữ', 'A', 'Số 252, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN187', 'KH187', 'Phạm Thị Em', '1998-02-12', 'Nữ', 'O', 'Số 16, Đường Trần Hưng Đạo, Quận 3, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN188', 'KH188', 'Lê Gia Em', '1982-01-22', 'Nam', 'A', 'Số 198, Đường Cách Mạng Tháng 8, Quận 5, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN189', 'KH189', 'Lê Khánh An', '1992-06-16', 'Nữ', 'A', 'Số 424, Đường Trần Hưng Đạo, Quận 5, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN190', 'KH190', 'Đỗ Minh Tuấn', '1985-12-20', 'Nữ', 'O', 'Số 891, Đường Điện Biên Phủ, Gò Vấp, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN191', 'KH191', 'Hoàng Minh Hương', '1985-06-03', 'Nữ', 'B', 'Số 72, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN192', 'KH192', 'Vũ Khánh Nam', '1998-02-16', 'Nam', 'AB', 'Số 752, Đường Phan Xích Long, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN193', 'KH193', 'Nguyễn Thị Hương', '1983-10-23', 'Nữ', 'O', 'Số 670, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN194', 'KH194', 'Đặng Minh Tuấn', '2016-06-22', 'Nam', 'O', 'Số 694, Đường Trần Hưng Đạo, Tân Bình, TP. Hồ Chí Minh', 'Suy tim', NULL);
INSERT INTO public.benh_nhan VALUES ('BN195', 'KH195', 'Đỗ Minh Linh', '1971-03-17', 'Nam', 'B', 'Số 724, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN196', 'KH196', 'Phạm Thanh Khôi', '2005-08-24', 'Nữ', 'O', 'Số 970, Đường Điện Biên Phủ, Quận 10, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN197', 'KH197', 'Nguyễn Hoàng Em', '2019-03-09', 'Nam', 'A', 'Số 927, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Rối loạn lo âu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN198', 'KH198', 'Đặng Minh Tuấn', '2024-12-29', 'Nam', 'B', 'Số 173, Đường Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN199', 'KH199', 'Bùi Thị Thảo', '2021-03-15', 'Nữ', 'O', 'Số 422, Đường Phan Xích Long, Quận 10, TP. Hồ Chí Minh', 'Mất ngủ kéo dài', NULL);
INSERT INTO public.benh_nhan VALUES ('BN200', 'KH200', 'Bùi Khánh Thảo', '2018-06-28', 'Nam', 'O', 'Số 990, Đường Điện Biên Phủ, Gò Vấp, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN201', 'KH201', 'Trần Hoàng Bình', '2003-11-02', 'Nam', 'A', 'Số 167, Đường Lê Lợi, Gò Vấp, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN202', 'KH202', 'Phạm Thị Quân', '1995-02-02', 'Nữ', 'A', 'Số 258, Đường Nguyễn Huệ, Tân Bình, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN203', 'KH203', 'Đặng Hoàng Linh', '1980-07-12', 'Nữ', 'A', 'Số 21, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN204', 'KH204', 'Vũ Văn An', '1998-09-05', 'Nữ', 'O', 'Số 835, Đường Trần Hưng Đạo, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN205', 'KH205', 'Vũ Thanh Khôi', '1970-01-18', 'Nữ', 'B', 'Số 50, Đường Cách Mạng Tháng 8, Tân Bình, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN206', 'KH206', 'Phạm Thanh Dũng', '1982-10-24', 'Nữ', 'A', 'Số 359, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN207', 'KH207', 'Phan Anh Nam', '1963-03-02', 'Nữ', 'B', 'Số 529, Đường Trần Hưng Đạo, Quận 7, TP. Hồ Chí Minh', 'Ung thư vú', NULL);
INSERT INTO public.benh_nhan VALUES ('BN208', 'KH208', 'Đặng Văn Thảo', '1962-07-25', 'Nữ', 'AB', 'Số 263, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN209', 'KH209', 'Trần Ngọc Dũng', '2016-10-25', 'Nam', 'A', 'Số 578, Đường Điện Biên Phủ, Gò Vấp, TP. Hồ Chí Minh', 'Viêm khớp dạng thấp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN210', 'KH210', 'Lê Minh Khôi', '1974-07-16', 'Nữ', 'B', 'Số 249, Đường Phan Xích Long, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Rối loạn mỡ máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN211', 'KH211', 'Phan Anh Hương', '1971-11-14', 'Nữ', 'A', 'Số 902, Đường Điện Biên Phủ, Quận 10, TP. Hồ Chí Minh', 'Ung thư gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN212', 'KH212', 'Đỗ Hoàng Khôi', '1985-02-20', 'Nữ', 'B', 'Số 749, Đường Phan Xích Long, Quận 7, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN213', 'KH213', 'Phạm Khánh Chi', '1969-09-08', 'Nam', 'B', 'Số 965, Đường Trần Hưng Đạo, Quận 10, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN214', 'KH214', 'Phan Anh Bình', '1986-02-06', 'Nữ', 'O', 'Số 841, Đường Nguyễn Huệ, Gò Vấp, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN215', 'KH215', 'Trần Anh Thảo', '2014-11-24', 'Nữ', 'A', 'Số 984, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Viêm gan B', NULL);
INSERT INTO public.benh_nhan VALUES ('BN216', 'KH216', 'Hoàng Gia Nam', '1984-06-12', 'Nam', 'O', 'Số 628, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN217', 'KH217', 'Đặng Thanh Chi', '1960-05-26', 'Nữ', 'AB', 'Số 35, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN218', 'KH218', 'Lê Ngọc An', '2010-01-05', 'Nữ', 'AB', 'Số 271, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN219', 'KH219', 'Hoàng Văn Quân', '1990-01-28', 'Nam', 'O', 'Số 550, Đường Điện Biên Phủ, Gò Vấp, TP. Hồ Chí Minh', 'Dị ứng thực phẩm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN220', 'KH220', 'Bùi Văn Thảo', '2018-04-04', 'Nam', 'O', 'Số 808, Đường Trần Hưng Đạo, Quận 3, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN221', 'KH221', 'Hoàng Văn Em', '1970-03-10', 'Nữ', 'B', 'Số 476, Đường Nguyễn Huệ, Tân Bình, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN222', 'KH222', 'Phan Ngọc Quân', '1983-05-30', 'Nữ', 'O', 'Số 778, Đường Điện Biên Phủ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN223', 'KH223', 'Phan Gia Khôi', '1965-08-29', 'Nữ', 'A', 'Số 469, Đường Nguyễn Huệ, Tân Bình, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN224', 'KH224', 'Phan Khánh Quân', '2008-10-25', 'Nữ', 'A', 'Số 894, Đường Trần Hưng Đạo, Gò Vấp, TP. Hồ Chí Minh', 'Rối loạn lo âu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN225', 'KH225', 'Nguyễn Văn Em', '1987-07-05', 'Nam', 'O', 'Số 7, Đường Cách Mạng Tháng 8, Quận 10, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN226', 'KH226', 'Trần Hoàng Khôi', '1965-07-27', 'Nữ', 'AB', 'Số 451, Đường Điện Biên Phủ, Quận 3, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN227', 'KH227', 'Phạm Gia An', '1960-01-08', 'Nữ', 'O', 'Số 910, Đường Điện Biên Phủ, Quận 5, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN228', 'KH228', 'Đặng Anh Em', '2007-11-29', 'Nam', 'AB', 'Số 885, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN229', 'KH229', 'Đặng Anh Chi', '1998-10-10', 'Nam', 'O', 'Số 495, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN230', 'KH230', 'Phan Hoàng An', '1998-03-22', 'Nữ', 'O', 'Số 464, Đường Lê Lợi, Gò Vấp, TP. Hồ Chí Minh', 'Mất ngủ kéo dài', NULL);
INSERT INTO public.benh_nhan VALUES ('BN231', 'KH231', 'Bùi Hoàng Thảo', '1983-12-26', 'Nữ', 'AB', 'Số 984, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN232', 'KH232', 'Nguyễn Thị Chi', '1996-09-27', 'Nữ', 'O', 'Số 416, Đường Lê Lợi, Gò Vấp, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN233', 'KH233', 'Trần Gia Thảo', '1974-03-22', 'Nam', 'O', 'Số 399, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN234', 'KH234', 'Trần Thanh Khôi', '1969-11-05', 'Nam', 'O', 'Số 106, Đường Cách Mạng Tháng 8, Quận 7, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN235', 'KH235', 'Bùi Ngọc Dũng', '2015-07-19', 'Nữ', 'A', 'Số 947, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN236', 'KH236', 'Vũ Văn Thảo', '1962-11-19', 'Nữ', 'A', 'Số 862, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN237', 'KH237', 'Lê Ngọc An', '1972-01-17', 'Nữ', 'A', 'Số 671, Đường Phan Xích Long, Quận 5, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN238', 'KH238', 'Lê Thị Tuấn', '2006-06-30', 'Nữ', 'O', 'Số 995, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN239', 'KH239', 'Vũ Gia Chi', '1995-03-06', 'Nữ', 'B', 'Số 732, Đường Điện Biên Phủ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN240', 'KH240', 'Phan Thị An', '2005-03-04', 'Nữ', 'B', 'Số 861, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN241', 'KH241', 'Đặng Gia Nam', '2025-05-31', 'Nữ', 'O', 'Số 632, Đường Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN242', 'KH242', 'Hoàng Khánh Nam', '2006-02-22', 'Nam', 'B', 'Số 814, Đường Lê Lợi, Gò Vấp, TP. Hồ Chí Minh', 'Bệnh tim mạch', NULL);
INSERT INTO public.benh_nhan VALUES ('BN243', 'KH243', 'Phan Anh Tuấn', '2014-07-24', 'Nam', 'A', 'Số 601, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN244', 'KH244', 'Phan Văn Bình', '1967-10-06', 'Nữ', 'O', 'Số 160, Đường Phan Xích Long, Quận 7, TP. Hồ Chí Minh', 'Ung thư gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN245', 'KH245', 'Trần Anh Khôi', '1963-10-04', 'Nam', 'B', 'Số 216, Đường Nguyễn Huệ, Tân Bình, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN246', 'KH246', 'Phan Minh Nam', '1994-06-23', 'Nữ', 'A', 'Số 534, Đường Cách Mạng Tháng 8, Quận 7, TP. Hồ Chí Minh', 'Mất ngủ kéo dài', NULL);
INSERT INTO public.benh_nhan VALUES ('BN247', 'KH247', 'Hoàng Gia Tuấn', '1964-11-04', 'Nam', 'AB', 'Số 739, Đường Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN248', 'KH248', 'Đỗ Hoàng Em', '1960-10-28', 'Nam', 'O', 'Số 151, Đường Phan Xích Long, Tân Bình, TP. Hồ Chí Minh', 'Dị ứng thực phẩm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN249', 'KH249', 'Bùi Văn Tuấn', '1968-12-23', 'Nam', 'B', 'Số 34, Đường Nguyễn Huệ, Gò Vấp, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN250', 'KH250', 'Nguyễn Thị Chi', '1997-12-31', 'Nam', 'AB', 'Số 6, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Thiếu máu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN251', 'KH251', 'Hoàng Anh Hương', '2012-10-15', 'Nam', 'O', 'Số 267, Đường Cách Mạng Tháng 8, Quận 3, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN252', 'KH252', 'Vũ Văn Chi', '1993-02-24', 'Nam', 'O', 'Số 528, Đường Cách Mạng Tháng 8, Tân Bình, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN253', 'KH253', 'Phan Anh Quân', '1988-06-17', 'Nữ', 'O', 'Số 449, Đường Điện Biên Phủ, Quận 5, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN254', 'KH254', 'Nguyễn Khánh Hương', '2025-08-10', 'Nữ', 'O', 'Số 806, Đường Điện Biên Phủ, Tân Bình, TP. Hồ Chí Minh', 'Ung thư vú', NULL);
INSERT INTO public.benh_nhan VALUES ('BN255', 'KH255', 'Hoàng Anh Tuấn', '2008-06-20', 'Nam', 'A', 'Số 956, Đường Trần Hưng Đạo, Quận 10, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN256', 'KH256', 'Hoàng Khánh Linh', '2021-09-08', 'Nam', 'AB', 'Số 781, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN257', 'KH257', 'Đặng Thị Bình', '1982-11-14', 'Nữ', 'A', 'Số 181, Đường Nguyễn Huệ, Gò Vấp, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN258', 'KH258', 'Vũ Thị Bình', '2018-02-27', 'Nam', 'O', 'Số 669, Đường Điện Biên Phủ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Dị ứng thuốc', NULL);
INSERT INTO public.benh_nhan VALUES ('BN259', 'KH259', 'Lê Thanh Linh', '2026-03-18', 'Nam', 'B', 'Số 439, Đường Điện Biên Phủ, Quận 7, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN260', 'KH260', 'Đặng Khánh Khôi', '2002-12-06', 'Nữ', 'AB', 'Số 364, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'sốt xuất huyết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN261', 'KH261', 'Trần Thanh Dũng', '2026-01-14', 'Nam', 'O', 'Số 298, Đường Phan Xích Long, Quận 10, TP. Hồ Chí Minh', 'Rối loạn lo âu', NULL);
INSERT INTO public.benh_nhan VALUES ('BN262', 'KH262', 'Phạm Thanh Khôi', '1989-03-05', 'Nam', 'AB', 'Số 299, Đường Điện Biên Phủ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Tăng huyết áp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN263', 'KH263', 'Đặng Hoàng Dũng', '2006-05-29', 'Nữ', 'B', 'Số 710, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN264', 'KH264', 'Bùi Văn Thảo', '2020-12-14', 'Nam', 'B', 'Số 685, Đường Điện Biên Phủ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN265', 'KH265', 'Đặng Ngọc Nam', '2012-09-11', 'Nữ', 'O', 'Số 163, Đường Điện Biên Phủ, Quận 7, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN266', 'KH266', 'Đặng Văn Tuấn', '1978-12-15', 'Nữ', 'O', 'Số 510, Đường Trần Hưng Đạo, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN267', 'KH267', 'Đỗ Khánh An', '1970-01-02', 'Nữ', 'B', 'Số 90, Đường Trần Hưng Đạo, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Dị ứng thuốc', NULL);
INSERT INTO public.benh_nhan VALUES ('BN268', 'KH268', 'Đặng Thị Bình', '1961-03-23', 'Nữ', 'A', 'Số 440, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', NULL);
INSERT INTO public.benh_nhan VALUES ('BN269', 'KH269', 'Đặng Thị Quân', '1968-07-03', 'Nam', 'B', 'Số 7, Đường Điện Biên Phủ, Quận 7, TP. Hồ Chí Minh', 'Suy thận mạn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN270', 'KH270', 'Trần Khánh An', '2022-03-12', 'Nam', 'O', 'Số 931, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Ung thư gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN271', 'KH271', 'Phan Gia Thảo', '1990-09-06', 'Nam', 'B', 'Số 133, Đường Điện Biên Phủ, Quận 5, TP. Hồ Chí Minh', 'Viêm khớp dạng thấp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN272', 'KH272', 'Nguyễn Gia Em', '1969-02-26', 'Nữ', 'B', 'Số 28, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Sỏi thận', NULL);
INSERT INTO public.benh_nhan VALUES ('BN273', 'KH273', 'Nguyễn Khánh Em', '2000-06-29', 'Nam', 'B', 'Số 880, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'sốt siêu vi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN274', 'KH274', 'Vũ Gia An', '2014-07-29', 'Nam', 'AB', 'Số 436, Đường Điện Biên Phủ, Quận 5, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN275', 'KH275', 'Đỗ Thị Em', '2002-01-30', 'Nữ', 'A', 'Số 60, Đường Trần Hưng Đạo, Quận 5, TP. Hồ Chí Minh', 'Viêm gan C', NULL);
INSERT INTO public.benh_nhan VALUES ('BN276', 'KH276', 'Lê Thị Dũng', '2000-06-06', 'Nam', 'AB', 'Số 142, Đường Cách Mạng Tháng 8, Quận 1, TP. Hồ Chí Minh', 'Thoái hóa khớp', NULL);
INSERT INTO public.benh_nhan VALUES ('BN277', 'KH277', 'Lê Anh Chi', '1981-08-23', 'Nam', 'B', 'Số 720, Đường Trần Hưng Đạo, Quận 7, TP. Hồ Chí Minh', 'Hen suyễn', NULL);
INSERT INTO public.benh_nhan VALUES ('BN278', 'KH278', 'Vũ Hoàng Nam', '1988-01-31', 'Nam', 'A', 'Số 428, Đường Cách Mạng Tháng 8, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN279', 'KH279', 'Đặng Thanh Chi', '1990-08-16', 'Nam', 'AB', 'Số 824, Đường Điện Biên Phủ, Tân Bình, TP. Hồ Chí Minh', 'Ung thư gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN280', 'KH280', 'Phạm Khánh Nam', '1989-07-21', 'Nam', 'B', 'Số 282, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN281', 'KH281', 'Phạm Gia An', '1974-11-16', 'Nữ', 'O', 'Số 287, Đường Cách Mạng Tháng 8, Quận 7, TP. Hồ Chí Minh', 'Gout', NULL);
INSERT INTO public.benh_nhan VALUES ('BN282', 'KH282', 'Đặng Ngọc Hương', '1969-11-08', 'Nam', 'A', 'Số 805, Đường Phan Xích Long, Quận 3, TP. Hồ Chí Minh', 'Trầm cảm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN283', 'KH283', 'Nguyễn Hoàng Thảo', '1981-02-19', 'Nam', 'A', 'Số 565, Đường Cách Mạng Tháng 8, Quận 7, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN284', 'KH284', 'Lê Hoàng Tuấn', '1987-12-22', 'Nữ', 'B', 'Số 651, Đường Trần Hưng Đạo, Quận 1, TP. Hồ Chí Minh', 'Không có', NULL);
INSERT INTO public.benh_nhan VALUES ('BN285', 'KH285', 'Đặng Khánh Quân', '1974-05-07', 'Nam', 'A', 'Số 960, Đường Trần Hưng Đạo, Quận 1, TP. Hồ Chí Minh', 'Suy tim', NULL);
INSERT INTO public.benh_nhan VALUES ('BN286', 'KH286', 'Lê Minh Linh', '2021-05-27', 'Nữ', 'B', 'Số 685, Đường Cách Mạng Tháng 8, Tân Bình, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN287', 'KH287', 'Đặng Thị Thảo', '1967-12-08', 'Nữ', 'O', 'Số 828, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN288', 'KH288', 'Hoàng Thị Nam', '1979-07-24', 'Nam', 'B', 'Số 366, Đường Cách Mạng Tháng 8, Quận 7, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN289', 'KH289', 'Bùi Văn Chi', '1998-08-12', 'Nam', 'O', 'Số 626, Đường Điện Biên Phủ, Quận 1, TP. Hồ Chí Minh', 'Tiểu đường tuýp 2', NULL);
INSERT INTO public.benh_nhan VALUES ('BN290', 'KH290', 'Phạm Ngọc Quân', '2012-03-20', 'Nữ', 'A', 'Số 558, Đường Nguyễn Huệ, Tân Bình, TP. Hồ Chí Minh', 'Tiểu đường tuýp 1', NULL);
INSERT INTO public.benh_nhan VALUES ('BN291', 'KH291', 'Trần Thị Dũng', '2026-01-15', 'Nữ', 'AB', 'Số 344, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Loãng xương', NULL);
INSERT INTO public.benh_nhan VALUES ('BN292', 'KH292', 'Đặng Hoàng Khôi', '1974-09-22', 'Nữ', 'AB', 'Số 179, Đường Điện Biên Phủ, Quận 7, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN293', 'KH293', 'Bùi Văn Bình', '1978-12-08', 'Nữ', 'A', 'Số 181, Đường Điện Biên Phủ, Quận 1, TP. Hồ Chí Minh', 'Ung thư phổi', NULL);
INSERT INTO public.benh_nhan VALUES ('BN294', 'KH294', 'Bùi Văn Linh', '2001-01-23', 'Nam', 'O', 'Số 978, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Dị ứng thời tiết', NULL);
INSERT INTO public.benh_nhan VALUES ('BN295', 'KH295', 'Phan Khánh Quân', '1984-11-30', 'Nữ', 'A', 'Số 278, Đường Điện Biên Phủ, Quận 1, TP. Hồ Chí Minh', 'Ung thư đại tràng', NULL);
INSERT INTO public.benh_nhan VALUES ('BN296', 'KH296', 'Phan Khánh An', '2012-12-01', 'Nam', 'B', 'Số 648, Đường Cách Mạng Tháng 8, Quận 5, TP. Hồ Chí Minh', 'Viêm phế quản mạn tính', NULL);
INSERT INTO public.benh_nhan VALUES ('BN297', 'KH297', 'Đỗ Minh Hương', '2004-03-01', 'Nam', 'B', 'Số 458, Đường Phan Xích Long, Quận 1, TP. Hồ Chí Minh', 'Xơ gan', NULL);
INSERT INTO public.benh_nhan VALUES ('BN298', 'KH298', 'Đỗ Khánh Quân', '2019-10-26', 'Nam', 'AB', 'Số 291, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Ung thư vú', NULL);
INSERT INTO public.benh_nhan VALUES ('BN299', 'KH299', 'Đỗ Anh Bình', '1990-06-06', 'Nam', 'O', 'Số 724, Đường Cách Mạng Tháng 8, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Dị ứng thực phẩm', NULL);
INSERT INTO public.benh_nhan VALUES ('BN300', 'KH300', 'Trần Gia Bình', '1960-06-14', 'Nữ', 'A', 'Số 629, Đường Cách Mạng Tháng 8, Quận 5, TP. Hồ Chí Minh', 'Mất ngủ kéo dài', NULL);
INSERT INTO public.benh_nhan VALUES ('BN301', 'KH301', 'Lê Nguyễn Minh Triết', '2006-06-13', 'Nam', 'O', 'KTX KHU B DHQG', 'Suy Tim', NULL);


--
-- TOC entry 5080 (class 0 OID 17174)
-- Dependencies: 225
-- Data for Name: chi_tiet_vat_tu; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ001', 'VT022', 4, 40000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ002', 'VT016', 5, 160000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ003', 'VT008', 1, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ004', 'VT031', 2, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ005', 'VT028', 4, 280000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ006', 'VT015', 3, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ007', 'VT008', 1, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ008', 'VT008', 1, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ009', 'VT013', 4, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ010', 'VT031', 1, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ011', 'VT005', 5, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ012', 'VT032', 4, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ013', 'VT023', 2, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ014', 'VT018', 5, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ015', 'VT018', 4, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ016', 'VT027', 2, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ017', 'VT002', 3, 250000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ018', 'VT022', 4, 40000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ019', 'VT026', 4, 65000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ020', 'VT027', 2, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ021', 'VT019', 3, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ022', 'VT031', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ023', 'VT002', 1, 250000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ024', 'VT001', 1, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ025', 'VT013', 1, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ026', 'VT006', 5, 180000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ027', 'VT002', 3, 250000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ028', 'VT010', 1, 450000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ029', 'VT015', 1, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ030', 'VT009', 3, 1200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ031', 'VT024', 5, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ032', 'VT018', 3, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ033', 'VT008', 1, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ034', 'VT007', 1, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ035', 'VT003', 5, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ036', 'VT017', 4, 110000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ037', 'VT021', 1, 20000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ038', 'VT015', 5, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ039', 'VT030', 1, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ040', 'VT030', 1, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ041', 'VT022', 1, 40000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ042', 'VT016', 3, 160000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ043', 'VT024', 1, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ044', 'VT014', 1, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ045', 'VT008', 3, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ046', 'VT009', 5, 1200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ047', 'VT025', 1, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ048', 'VT029', 4, 135000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ049', 'VT031', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ050', 'VT021', 2, 20000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ051', 'VT004', 3, 35000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ052', 'VT023', 4, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ053', 'VT026', 2, 65000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ054', 'VT024', 1, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ055', 'VT004', 2, 35000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ056', 'VT002', 4, 250000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ057', 'VT023', 2, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ058', 'VT015', 5, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ059', 'VT016', 1, 160000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ060', 'VT011', 1, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ061', 'VT018', 4, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ062', 'VT031', 2, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ063', 'VT030', 2, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ064', 'VT003', 4, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ065', 'VT025', 3, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ066', 'VT011', 4, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ067', 'VT023', 2, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ068', 'VT017', 2, 110000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ069', 'VT029', 2, 135000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ070', 'VT018', 3, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ071', 'VT001', 4, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ072', 'VT027', 5, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ073', 'VT006', 2, 180000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ074', 'VT030', 2, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ075', 'VT008', 2, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ076', 'VT011', 5, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ077', 'VT012', 5, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ078', 'VT031', 4, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ079', 'VT005', 2, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ080', 'VT008', 2, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ081', 'VT014', 3, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ082', 'VT012', 2, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ083', 'VT026', 3, 65000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ084', 'VT008', 2, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ085', 'VT024', 4, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ086', 'VT016', 4, 160000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ087', 'VT023', 1, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ088', 'VT017', 4, 110000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ089', 'VT013', 2, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ090', 'VT018', 4, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ091', 'VT024', 1, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ092', 'VT030', 5, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ093', 'VT032', 1, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ094', 'VT012', 5, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ095', 'VT013', 3, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ096', 'VT007', 2, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ097', 'VT015', 1, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ098', 'VT018', 4, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ099', 'VT030', 5, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ100', 'VT006', 2, 180000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ101', 'VT021', 4, 20000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ102', 'VT025', 3, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ103', 'VT001', 2, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ104', 'VT018', 5, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ105', 'VT017', 4, 110000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ106', 'VT019', 1, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ107', 'VT019', 3, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ108', 'VT008', 3, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ109', 'VT026', 1, 65000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ110', 'VT028', 2, 280000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ111', 'VT032', 3, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ112', 'VT013', 4, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ113', 'VT005', 4, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ114', 'VT019', 3, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ115', 'VT024', 1, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ116', 'VT002', 1, 250000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ117', 'VT031', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ118', 'VT012', 4, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ119', 'VT008', 4, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ120', 'VT016', 1, 160000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ121', 'VT028', 4, 280000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ122', 'VT031', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ123', 'VT031', 4, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ124', 'VT023', 2, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ125', 'VT009', 1, 1200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ126', 'VT021', 5, 20000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ127', 'VT031', 3, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ128', 'VT022', 3, 40000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ129', 'VT027', 3, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ130', 'VT032', 4, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ131', 'VT012', 5, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ132', 'VT023', 2, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ133', 'VT005', 2, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ134', 'VT032', 5, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ135', 'VT013', 2, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ136', 'VT014', 4, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ137', 'VT026', 1, 65000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ138', 'VT008', 5, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ139', 'VT017', 4, 110000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ140', 'VT023', 1, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ141', 'VT024', 3, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ142', 'VT012', 1, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ143', 'VT015', 4, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ144', 'VT023', 4, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ145', 'VT023', 2, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ146', 'VT023', 4, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ147', 'VT027', 2, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ148', 'VT011', 4, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ149', 'VT008', 5, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ150', 'VT015', 3, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ151', 'VT014', 4, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ152', 'VT031', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ153', 'VT019', 1, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ154', 'VT032', 5, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ155', 'VT030', 3, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ156', 'VT009', 3, 1200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ157', 'VT031', 1, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ158', 'VT007', 4, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ159', 'VT016', 1, 160000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ160', 'VT018', 4, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ161', 'VT025', 2, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ162', 'VT030', 3, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ163', 'VT031', 4, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ164', 'VT023', 1, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ165', 'VT012', 5, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ166', 'VT001', 5, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ167', 'VT014', 4, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ168', 'VT006', 5, 180000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ169', 'VT008', 4, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ170', 'VT023', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ171', 'VT002', 5, 250000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ172', 'VT005', 1, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ173', 'VT018', 5, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ174', 'VT019', 2, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ175', 'VT027', 2, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ176', 'VT011', 5, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ177', 'VT005', 3, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ178', 'VT023', 4, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ179', 'VT006', 2, 180000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ180', 'VT024', 5, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ181', 'VT025', 4, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ182', 'VT024', 3, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ183', 'VT015', 2, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ184', 'VT029', 3, 135000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ185', 'VT001', 3, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ186', 'VT019', 1, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ187', 'VT008', 5, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ188', 'VT025', 1, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ189', 'VT029', 4, 135000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ190', 'VT011', 1, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ191', 'VT014', 5, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ192', 'VT011', 2, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ193', 'VT005', 3, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ194', 'VT017', 2, 110000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ195', 'VT011', 1, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ196', 'VT005', 2, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ197', 'VT001', 2, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ198', 'VT027', 1, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ199', 'VT029', 1, 135000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ200', 'VT017', 2, 110000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ201', 'VT029', 4, 135000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ202', 'VT014', 2, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ203', 'VT012', 2, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ204', 'VT023', 1, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ205', 'VT001', 3, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ206', 'VT019', 1, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ207', 'VT014', 3, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ208', 'VT019', 4, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ209', 'VT011', 5, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ210', 'VT025', 4, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ211', 'VT024', 4, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ212', 'VT005', 1, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ213', 'VT030', 2, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ214', 'VT019', 5, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ215', 'VT023', 2, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ216', 'VT018', 1, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ217', 'VT030', 5, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ218', 'VT023', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ219', 'VT009', 1, 1200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ220', 'VT011', 3, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ221', 'VT008', 2, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ222', 'VT013', 5, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ223', 'VT018', 2, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ224', 'VT017', 3, 110000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ225', 'VT021', 2, 20000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ226', 'VT006', 2, 180000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ227', 'VT006', 3, 180000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ228', 'VT022', 2, 40000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ229', 'VT019', 1, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ230', 'VT027', 4, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ231', 'VT012', 1, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ232', 'VT015', 3, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ233', 'VT031', 3, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ234', 'VT012', 1, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ235', 'VT010', 1, 450000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ236', 'VT031', 1, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ237', 'VT008', 5, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ238', 'VT028', 4, 280000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ239', 'VT002', 4, 250000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ240', 'VT015', 1, 95000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ241', 'VT023', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ242', 'VT022', 3, 40000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ243', 'VT031', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ244', 'VT006', 3, 180000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ245', 'VT003', 4, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ246', 'VT025', 1, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ247', 'VT027', 5, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ248', 'VT024', 3, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ249', 'VT005', 5, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ250', 'VT023', 1, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ251', 'VT031', 4, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ252', 'VT001', 3, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ253', 'VT029', 3, 135000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ254', 'VT022', 5, 40000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ255', 'VT008', 4, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ256', 'VT018', 4, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ257', 'VT032', 2, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ258', 'VT023', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ259', 'VT003', 1, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ260', 'VT013', 2, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ261', 'VT026', 3, 65000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ262', 'VT016', 2, 160000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ263', 'VT008', 1, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ264', 'VT012', 3, 200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ265', 'VT001', 5, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ266', 'VT008', 3, 850000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ267', 'VT020', 3, 25000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ268', 'VT025', 1, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ269', 'VT018', 4, 220000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ270', 'VT004', 2, 35000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ271', 'VT003', 3, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ272', 'VT017', 3, 110000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ273', 'VT009', 2, 1200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ274', 'VT023', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ275', 'VT023', 3, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ276', 'VT019', 4, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ277', 'VT001', 2, 150000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ278', 'VT030', 4, 310000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ279', 'VT014', 2, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ280', 'VT029', 3, 135000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ281', 'VT028', 5, 280000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ282', 'VT024', 4, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ283', 'VT022', 3, 40000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ284', 'VT002', 1, 250000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ285', 'VT019', 1, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ286', 'VT027', 5, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ287', 'VT013', 3, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ288', 'VT016', 3, 160000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ289', 'VT019', 1, 45000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ290', 'VT025', 1, 85000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ291', 'VT009', 1, 1200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ292', 'VT032', 3, 3000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ293', 'VT031', 5, 15000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ294', 'VT027', 4, 120000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ295', 'VT009', 4, 1200000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ296', 'VT005', 1, 650000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ297', 'VT024', 4, 1500000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ298', 'VT014', 2, 320000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ299', 'VT006', 1, 180000.00);
INSERT INTO public.chi_tiet_vat_tu VALUES ('KQ300', 'VT003', 4, 120000.00);


--
-- TOC entry 5075 (class 0 OID 17097)
-- Dependencies: 220
-- Data for Name: chuyen_khoa; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chuyen_khoa VALUES ('CK001', 'Nhi Lão');
INSERT INTO public.chuyen_khoa VALUES ('CK002', 'Phục hồi chức năng');
INSERT INTO public.chuyen_khoa VALUES ('CK003', 'Nội tổng quát');
INSERT INTO public.chuyen_khoa VALUES ('CK004', 'Ngoại thần kinh');
INSERT INTO public.chuyen_khoa VALUES ('CK005', 'Sản phụ khoa');
INSERT INTO public.chuyen_khoa VALUES ('CK006', 'Tai Mũi Họng');
INSERT INTO public.chuyen_khoa VALUES ('CK007', 'Răng Hàm Mặt');
INSERT INTO public.chuyen_khoa VALUES ('CK008', 'Da liễu');
INSERT INTO public.chuyen_khoa VALUES ('CK009', 'Nhi Lão');


--
-- TOC entry 5082 (class 0 OID 17210)
-- Dependencies: 227
-- Data for Name: danh_gia; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.danh_gia VALUES ('DG002', 'LH002', 3, 'Chất lượng tạm ổn.', NULL, '2026-01-30 22:34:10', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG035', 'LH035', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-12-14 19:37:41', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG036', 'LH036', 4, 'Dịch vụ tốt.', NULL, '2026-01-03 03:23:28', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG037', 'LH037', 3, 'Phòng khám hơi đông.', NULL, '2026-01-11 21:59:59', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG038', 'LH038', 1, 'Sẽ không quay lại.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-03-11 03:33:23', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG039', 'LH039', 3, 'Chất lượng tạm ổn.', NULL, '2025-08-29 16:41:29', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG040', 'LH040', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-04-13 20:59:19', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG041', 'LH041', 4, 'Bác sĩ tận tâm.', NULL, '2026-03-07 13:03:39', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG042', 'LH042', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-02-27 19:37:42', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG043', 'LH043', 5, 'Tuyệt vời!', NULL, '2026-02-21 22:52:35', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG044', 'LH044', 2, 'Thái độ nhân viên chưa tốt.', 'Chờ đợi quá lâu', '2025-03-31 17:29:54', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG045', 'LH045', 5, 'Tuyệt vời!', NULL, '2025-07-17 03:59:46', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG046', 'LH046', 1, 'Dịch vụ quá tệ.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-09-19 01:02:06', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG047', 'LH047', 3, 'Chất lượng tạm ổn.', NULL, '2025-10-30 10:12:21', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG048', 'LH048', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-04-18 17:09:26', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG049', 'LH049', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-11-09 01:51:45', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG050', 'LH050', 4, 'Dịch vụ tốt.', NULL, '2026-02-13 13:40:09', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG051', 'LH051', 4, 'Dịch vụ tốt.', NULL, '2025-02-27 10:05:51', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG052', 'LH052', 1, 'Rất thất vọng.', 'Vệ sinh phòng khám không đảm bảo', '2025-06-04 07:06:48', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG053', 'LH053', 1, 'Sẽ không quay lại.', 'Bác sĩ khám quá nhanh', '2025-10-15 19:42:43', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG054', 'LH054', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-09-15 01:00:49', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG055', 'LH055', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-02-22 03:20:37', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG056', 'LH056', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-04-16 08:31:49', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG057', 'LH057', 4, 'Hài lòng với trải nghiệm.', NULL, '2026-03-06 12:35:55', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG058', 'LH058', 5, 'Tuyệt vời!', NULL, '2025-07-07 19:14:47', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG059', 'LH059', 1, 'Sẽ không quay lại.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-07-17 08:21:46', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG060', 'LH060', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-09-24 07:14:56', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG061', 'LH061', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-06-09 01:57:42', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG062', 'LH062', 4, 'Bác sĩ tận tâm.', NULL, '2025-02-21 22:24:12', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG063', 'LH063', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-07-31 04:56:48', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG064', 'LH064', 4, 'Bác sĩ tận tâm.', NULL, '2025-08-24 20:36:03', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG065', 'LH065', 4, 'Dịch vụ tốt.', NULL, '2025-07-25 05:57:13', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG066', 'LH066', 4, 'Bác sĩ tận tâm.', NULL, '2025-12-01 05:13:29', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG067', 'LH067', 1, 'Sẽ không quay lại.', 'Chờ đợi quá lâu', '2025-08-25 15:12:33', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG068', 'LH068', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-12-03 13:28:28', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG069', 'LH069', 3, 'Chất lượng tạm ổn.', NULL, '2026-03-31 12:12:51', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG070', 'LH070', 4, 'Dịch vụ tốt.', NULL, '2025-02-17 18:20:12', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG071', 'LH071', 1, 'Rất thất vọng.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-04-28 16:37:34', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG072', 'LH072', 3, 'Phòng khám hơi đông.', NULL, '2025-06-21 18:27:53', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG073', 'LH073', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-06-15 10:51:31', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG074', 'LH074', 4, 'Bác sĩ tận tâm.', NULL, '2025-03-09 13:13:25', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG075', 'LH075', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-05-12 02:05:28', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG076', 'LH076', 1, 'Sẽ không quay lại.', 'Chờ đợi quá lâu', '2026-01-07 16:07:41', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG077', 'LH077', 4, 'Bác sĩ tận tâm.', NULL, '2025-11-27 23:31:55', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG078', 'LH078', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-07-16 10:25:04', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG079', 'LH079', 3, 'Thời gian chờ hơi lâu.', NULL, '2026-03-21 05:58:24', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG080', 'LH080', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-06-22 21:53:41', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG081', 'LH081', 1, 'Rất thất vọng.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-05-29 01:12:49', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG082', 'LH082', 1, 'Sẽ không quay lại.', 'Chờ đợi quá lâu', '2025-05-11 10:20:32', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG083', 'LH083', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-05-14 20:46:36', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG084', 'LH084', 1, 'Sẽ không quay lại.', 'Bác sĩ khám quá nhanh', '2025-06-23 23:24:37', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG085', 'LH085', 4, 'Bác sĩ tận tâm.', NULL, '2025-04-10 13:44:59', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG086', 'LH086', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-01-10 22:39:13', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG087', 'LH087', 4, 'Bác sĩ tận tâm.', NULL, '2026-03-11 04:47:29', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG088', 'LH088', 4, 'Hài lòng với trải nghiệm.', NULL, '2026-03-09 08:27:06', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG089', 'LH089', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-10-23 02:24:12', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG090', 'LH090', 1, 'Rất thất vọng.', 'Bác sĩ khám quá nhanh', '2025-12-15 18:44:36', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG091', 'LH091', 2, 'Không hài lòng lắm.', 'Bác sĩ khám quá nhanh', '2025-05-20 22:05:22', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG092', 'LH092', 4, 'Dịch vụ tốt.', NULL, '2025-11-26 07:19:25', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG093', 'LH093', 1, 'Rất thất vọng.', 'Chờ đợi quá lâu', '2026-03-21 17:14:53', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG094', 'LH094', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-03-03 09:17:15', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG095', 'LH095', 2, 'Không hài lòng lắm.', 'Vệ sinh phòng khám không đảm bảo', '2025-10-28 08:04:52', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG096', 'LH096', 1, 'Dịch vụ quá tệ.', 'Vệ sinh phòng khám không đảm bảo', '2025-01-08 14:20:56', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG097', 'LH097', 4, 'Dịch vụ tốt.', NULL, '2025-02-15 17:46:06', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG098', 'LH098', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2026-02-02 20:37:42', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG099', 'LH099', 4, 'Dịch vụ tốt.', NULL, '2026-01-23 03:15:11', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG100', 'LH100', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-07-10 01:52:46', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG101', 'LH101', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-01-20 04:16:55', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG102', 'LH102', 5, 'Tuyệt vời!', NULL, '2026-02-10 13:33:44', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG103', 'LH103', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-06-08 15:17:14', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG104', 'LH104', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-08-30 00:11:01', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG105', 'LH105', 3, 'Chất lượng tạm ổn.', NULL, '2025-02-28 14:10:55', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG106', 'LH106', 4, 'Dịch vụ tốt.', NULL, '2025-05-04 06:26:24', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG107', 'LH107', 5, 'Tuyệt vời!', NULL, '2025-08-30 04:39:11', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG108', 'LH108', 5, 'Tuyệt vời!', NULL, '2025-01-30 01:14:38', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG109', 'LH109', 1, 'Dịch vụ quá tệ.', 'Chờ đợi quá lâu', '2025-07-16 13:03:48', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG110', 'LH110', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-03-08 14:39:26', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG111', 'LH111', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-07-28 05:07:34', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG112', 'LH112', 3, 'Phòng khám hơi đông.', NULL, '2025-05-18 20:15:32', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG113', 'LH113', 4, 'Dịch vụ tốt.', NULL, '2026-03-13 13:44:29', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG114', 'LH114', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-01-19 23:59:50', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG115', 'LH115', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2025-10-07 01:23:35', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG116', 'LH116', 3, 'Phòng khám hơi đông.', NULL, '2025-06-20 22:50:27', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG117', 'LH117', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2026-03-15 06:48:38', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG118', 'LH118', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2026-02-27 04:04:39', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG119', 'LH119', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-08-25 03:59:00', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG120', 'LH120', 4, 'Hài lòng với trải nghiệm.', NULL, '2026-01-03 17:44:55', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG121', 'LH121', 5, 'Tuyệt vời!', NULL, '2025-01-30 15:33:10', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG122', 'LH122', 2, 'Không hài lòng lắm.', 'Vệ sinh phòng khám không đảm bảo', '2025-05-07 01:32:22', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG123', 'LH123', 1, 'Rất thất vọng.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-04-01 01:46:16', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG124', 'LH124', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-08-03 05:54:27', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG125', 'LH125', 5, 'Tuyệt vời!', NULL, '2025-11-16 12:01:53', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG126', 'LH126', 1, 'Dịch vụ quá tệ.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-04-20 12:32:45', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG127', 'LH127', 1, 'Dịch vụ quá tệ.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-11-13 00:22:39', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG128', 'LH128', 5, 'Rất hài lòng với bác sĩ.', NULL, '2026-01-27 06:48:30', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG129', 'LH129', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-09-28 00:48:46', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG130', 'LH130', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2025-04-03 02:51:00', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG131', 'LH131', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-02-25 14:30:22', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG132', 'LH132', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-11-04 10:34:31', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG133', 'LH133', 1, 'Rất thất vọng.', 'Bác sĩ khám quá nhanh', '2025-10-21 16:10:41', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG134', 'LH134', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-01-22 22:45:11', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG135', 'LH135', 3, 'Phòng khám hơi đông.', NULL, '2026-04-09 02:41:03', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG136', 'LH136', 3, 'Chất lượng tạm ổn.', NULL, '2025-12-23 03:04:02', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG137', 'LH137', 2, 'Thái độ nhân viên chưa tốt.', 'Chờ đợi quá lâu', '2026-01-27 11:10:28', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG138', 'LH138', 1, 'Dịch vụ quá tệ.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-03-07 17:07:48', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG139', 'LH139', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-08-05 14:24:50', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG140', 'LH140', 1, 'Rất thất vọng.', 'Chờ đợi quá lâu', '2026-03-12 05:46:07', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG141', 'LH141', 3, 'Chất lượng tạm ổn.', NULL, '2025-12-26 22:20:15', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG142', 'LH142', 5, 'Tuyệt vời!', NULL, '2025-11-19 02:16:31', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG143', 'LH143', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-06-09 10:37:41', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG144', 'LH144', 3, 'Thời gian chờ hơi lâu.', NULL, '2026-03-26 01:02:22', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG145', 'LH145', 2, 'Thái độ nhân viên chưa tốt.', 'Bác sĩ khám quá nhanh', '2025-06-04 23:05:29', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG146', 'LH146', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-12-16 02:58:20', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG147', 'LH147', 4, 'Bác sĩ tận tâm.', NULL, '2025-09-30 19:52:04', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG148', 'LH148', 1, 'Sẽ không quay lại.', 'Chờ đợi quá lâu', '2026-02-01 12:22:38', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG149', 'LH149', 3, 'Chất lượng tạm ổn.', NULL, '2025-11-19 05:52:52', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG150', 'LH150', 5, 'Tuyệt vời!', NULL, '2025-08-29 05:20:57', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG151', 'LH151', 5, 'Rất hài lòng với bác sĩ.', NULL, '2026-02-18 09:53:45', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG152', 'LH152', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-07-02 17:43:00', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG153', 'LH153', 3, 'Chất lượng tạm ổn.', NULL, '2025-07-03 22:21:49', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG154', 'LH154', 1, 'Dịch vụ quá tệ.', 'Chờ đợi quá lâu', '2026-04-02 19:55:25', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG155', 'LH155', 1, 'Rất thất vọng.', 'Bác sĩ khám quá nhanh', '2025-08-04 12:32:15', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG156', 'LH156', 5, 'Tuyệt vời!', NULL, '2025-09-21 07:02:02', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG157', 'LH157', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-06-16 18:45:29', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG158', 'LH158', 1, 'Rất thất vọng.', 'Bác sĩ khám quá nhanh', '2025-03-10 16:26:37', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG159', 'LH159', 4, 'Dịch vụ tốt.', NULL, '2026-01-23 11:42:48', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG160', 'LH160', 1, 'Dịch vụ quá tệ.', 'Vệ sinh phòng khám không đảm bảo', '2025-03-05 07:58:49', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG161', 'LH161', 5, 'Tuyệt vời!', NULL, '2025-01-14 06:46:23', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG162', 'LH162', 1, 'Dịch vụ quá tệ.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-05-19 10:30:07', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG163', 'LH163', 3, 'Thời gian chờ hơi lâu.', NULL, '2026-01-14 20:00:43', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG164', 'LH164', 5, 'Tuyệt vời!', NULL, '2025-07-22 06:04:55', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG165', 'LH165', 2, 'Không hài lòng lắm.', 'Bác sĩ khám quá nhanh', '2025-03-10 07:43:39', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG166', 'LH166', 1, 'Sẽ không quay lại.', 'Bác sĩ khám quá nhanh', '2025-07-17 00:37:25', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG167', 'LH167', 3, 'Phòng khám hơi đông.', NULL, '2025-01-30 07:33:42', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG168', 'LH168', 2, 'Không hài lòng lắm.', 'Vệ sinh phòng khám không đảm bảo', '2025-01-19 17:40:12', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG169', 'LH169', 1, 'Dịch vụ quá tệ.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-01-06 12:13:30', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG170', 'LH170', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-11-09 10:10:46', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG171', 'LH171', 4, 'Dịch vụ tốt.', NULL, '2025-06-18 22:32:44', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG172', 'LH172', 3, 'Chất lượng tạm ổn.', NULL, '2025-01-03 07:18:46', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG173', 'LH173', 5, 'Rất hài lòng với bác sĩ.', NULL, '2026-03-29 01:16:38', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG174', 'LH174', 4, 'Dịch vụ tốt.', NULL, '2025-02-14 02:36:47', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG175', 'LH175', 2, 'Thái độ nhân viên chưa tốt.', 'Bác sĩ khám quá nhanh', '2025-01-30 15:38:21', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG176', 'LH176', 4, 'Bác sĩ tận tâm.', NULL, '2025-10-02 01:19:40', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG177', 'LH177', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-05-06 20:45:00', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG178', 'LH178', 4, 'Bác sĩ tận tâm.', NULL, '2025-12-15 05:18:19', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG179', 'LH179', 3, 'Phòng khám hơi đông.', NULL, '2025-08-25 16:41:59', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG180', 'LH180', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2026-03-08 19:42:45', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG181', 'LH181', 1, 'Dịch vụ quá tệ.', 'Bác sĩ khám quá nhanh', '2025-01-14 23:42:21', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG182', 'LH182', 1, 'Rất thất vọng.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-04-08 16:42:36', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG183', 'LH183', 3, 'Chất lượng tạm ổn.', NULL, '2025-02-24 12:44:39', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG184', 'LH184', 2, 'Thái độ nhân viên chưa tốt.', 'Chờ đợi quá lâu', '2025-06-22 09:35:39', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG185', 'LH185', 3, 'Chất lượng tạm ổn.', NULL, '2025-04-23 12:01:44', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG186', 'LH186', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-04-15 08:57:04', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG187', 'LH187', 1, 'Dịch vụ quá tệ.', 'Vệ sinh phòng khám không đảm bảo', '2025-10-27 11:57:07', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG188', 'LH188', 1, 'Rất thất vọng.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-03-01 07:37:11', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG189', 'LH189', 3, 'Chất lượng tạm ổn.', NULL, '2025-04-13 13:02:04', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG190', 'LH190', 1, 'Rất thất vọng.', 'Vệ sinh phòng khám không đảm bảo', '2025-09-20 04:45:12', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG191', 'LH191', 2, 'Thái độ nhân viên chưa tốt.', 'Chờ đợi quá lâu', '2026-01-26 21:44:08', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG192', 'LH192', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-05-13 15:56:47', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG193', 'LH193', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-03-30 06:05:17', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG194', 'LH194', 2, 'Không hài lòng lắm.', 'Vệ sinh phòng khám không đảm bảo', '2025-05-28 07:56:36', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG195', 'LH195', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-05-21 15:40:28', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG196', 'LH196', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-09-05 15:09:43', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG197', 'LH197', 1, 'Rất thất vọng.', 'Bác sĩ khám quá nhanh', '2025-08-21 10:57:54', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG198', 'LH198', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-02-10 21:08:13', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG199', 'LH199', 4, 'Dịch vụ tốt.', NULL, '2025-08-31 11:16:42', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG200', 'LH200', 5, 'Rất hài lòng với bác sĩ.', NULL, '2026-01-20 15:35:54', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG201', 'LH201', 4, 'Dịch vụ tốt.', NULL, '2025-02-13 20:13:20', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG202', 'LH202', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-03-13 16:15:51', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG203', 'LH203', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-02-06 09:53:22', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG204', 'LH204', 5, 'Tuyệt vời!', NULL, '2025-07-20 01:28:22', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG205', 'LH205', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-12-03 01:58:40', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG207', 'LH207', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-04-18 08:36:03', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG208', 'LH208', 4, 'Bác sĩ tận tâm.', NULL, '2025-05-13 04:31:07', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG209', 'LH209', 4, 'Hài lòng với trải nghiệm.', NULL, '2026-04-10 14:25:36', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG210', 'LH210', 5, 'Tuyệt vời!', NULL, '2025-05-21 10:07:22', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG211', 'LH211', 1, 'Rất thất vọng.', 'Chờ đợi quá lâu', '2025-12-19 12:59:15', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG212', 'LH212', 2, 'Không hài lòng lắm.', 'Vệ sinh phòng khám không đảm bảo', '2025-10-23 03:04:57', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG213', 'LH213', 1, 'Dịch vụ quá tệ.', 'Bác sĩ khám quá nhanh', '2025-10-07 07:45:33', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG214', 'LH214', 4, 'Dịch vụ tốt.', NULL, '2025-01-31 18:55:08', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG215', 'LH215', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-07-10 13:45:20', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG216', 'LH216', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-07-24 13:50:22', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG217', 'LH217', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2025-04-23 02:47:49', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG218', 'LH218', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-11-20 06:27:07', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG219', 'LH219', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-09-27 02:06:20', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG220', 'LH220', 1, 'Sẽ không quay lại.', 'Vệ sinh phòng khám không đảm bảo', '2025-06-06 11:20:36', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG221', 'LH221', 4, 'Bác sĩ tận tâm.', NULL, '2025-08-28 17:48:58', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG222', 'LH222', 3, 'Chất lượng tạm ổn.', NULL, '2025-03-16 22:23:59', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG223', 'LH223', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-07-31 20:23:29', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG224', 'LH224', 1, 'Rất thất vọng.', 'Vệ sinh phòng khám không đảm bảo', '2025-11-05 11:29:22', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG225', 'LH225', 5, 'Rất hài lòng với bác sĩ.', NULL, '2026-03-09 00:11:43', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG226', 'LH226', 4, 'Dịch vụ tốt.', NULL, '2025-01-29 23:10:18', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG227', 'LH227', 2, 'Thái độ nhân viên chưa tốt.', 'Bác sĩ khám quá nhanh', '2025-09-12 19:28:01', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG228', 'LH228', 2, 'Thái độ nhân viên chưa tốt.', 'Vệ sinh phòng khám không đảm bảo', '2025-05-09 12:53:27', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG229', 'LH229', 4, 'Dịch vụ tốt.', NULL, '2025-12-15 08:05:41', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG230', 'LH230', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-07-16 13:30:14', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG231', 'LH231', 3, 'Chất lượng tạm ổn.', NULL, '2026-01-12 15:51:19', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG232', 'LH232', 3, 'Phòng khám hơi đông.', NULL, '2025-05-24 15:49:42', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG233', 'LH233', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2025-11-18 07:04:27', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG234', 'LH234', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-08-31 06:28:01', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG235', 'LH235', 4, 'Dịch vụ tốt.', NULL, '2025-03-20 19:44:14', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG236', 'LH236', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-01-12 10:27:48', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG237', 'LH237', 5, 'Rất hài lòng với bác sĩ.', NULL, '2026-02-08 08:13:22', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG238', 'LH238', 3, 'Phòng khám hơi đông.', NULL, '2025-07-15 14:27:02', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG239', 'LH239', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-10-07 20:27:38', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG240', 'LH240', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-08-21 18:19:54', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG241', 'LH241', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-01-22 08:38:28', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG242', 'LH242', 2, 'Thái độ nhân viên chưa tốt.', 'Chờ đợi quá lâu', '2025-05-02 23:50:56', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG243', 'LH243', 1, 'Dịch vụ quá tệ.', 'Vệ sinh phòng khám không đảm bảo', '2025-01-10 09:41:50', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG244', 'LH244', 1, 'Rất thất vọng.', 'Bác sĩ khám quá nhanh', '2025-12-03 01:41:32', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG245', 'LH245', 5, 'Rất hài lòng với bác sĩ.', NULL, '2026-02-21 22:16:14', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG246', 'LH246', 2, 'Không hài lòng lắm.', 'Bác sĩ khám quá nhanh', '2026-02-08 06:40:36', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG247', 'LH247', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2025-07-27 19:37:16', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG248', 'LH248', 1, 'Dịch vụ quá tệ.', 'Chờ đợi quá lâu', '2025-02-01 12:45:57', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG249', 'LH249', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-11-23 00:49:21', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG250', 'LH250', 5, 'Rất hài lòng với bác sĩ.', NULL, '2026-03-27 20:27:15', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG251', 'LH251', 3, 'Phòng khám hơi đông.', NULL, '2025-01-16 09:37:30', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG252', 'LH252', 1, 'Rất thất vọng.', 'Vệ sinh phòng khám không đảm bảo', '2026-02-28 19:47:10', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG253', 'LH253', 1, 'Rất thất vọng.', 'Bác sĩ khám quá nhanh', '2025-05-28 06:43:51', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG254', 'LH254', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-03-19 07:38:27', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG255', 'LH255', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-08-11 14:18:22', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG256', 'LH256', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-06-18 07:39:07', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG257', 'LH257', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-03-12 12:50:07', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG258', 'LH258', 5, 'Tuyệt vời!', NULL, '2025-06-25 18:08:48', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG259', 'LH259', 1, 'Sẽ không quay lại.', 'Vệ sinh phòng khám không đảm bảo', '2026-02-21 11:31:54', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG260', 'LH260', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-07-12 05:04:41', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG261', 'LH261', 2, 'Thái độ nhân viên chưa tốt.', 'Chờ đợi quá lâu', '2025-12-13 20:59:53', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG262', 'LH262', 3, 'Phòng khám hơi đông.', NULL, '2025-10-03 23:41:15', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG263', 'LH263', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-01-22 04:43:06', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG264', 'LH264', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-11-08 17:33:31', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG265', 'LH265', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-02-09 15:46:25', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG266', 'LH266', 5, 'Tuyệt vời!', NULL, '2026-01-09 03:58:55', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG267', 'LH267', 5, 'Tuyệt vời!', NULL, '2025-05-18 21:55:26', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG268', 'LH268', 3, 'Thời gian chờ hơi lâu.', NULL, '2025-11-16 03:33:33', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG269', 'LH269', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-11-10 20:06:20', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG270', 'LH270', 5, 'Tuyệt vời!', NULL, '2025-05-16 04:52:08', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG271', 'LH271', 4, 'Dịch vụ tốt.', NULL, '2025-01-31 05:44:41', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG272', 'LH272', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-03-16 00:07:05', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG273', 'LH273', 2, 'Thái độ nhân viên chưa tốt.', 'Chờ đợi quá lâu', '2025-02-05 21:01:04', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG274', 'LH274', 4, 'Bác sĩ tận tâm.', NULL, '2026-02-14 20:38:29', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG275', 'LH275', 3, 'Chất lượng tạm ổn.', NULL, '2025-07-05 16:28:09', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG276', 'LH276', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2025-08-21 18:57:48', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG277', 'LH277', 4, 'Dịch vụ tốt.', NULL, '2025-07-27 10:28:45', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG278', 'LH278', 1, 'Rất thất vọng.', 'Chờ đợi quá lâu', '2025-07-16 22:26:29', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG279', 'LH279', 3, 'Chất lượng tạm ổn.', NULL, '2025-07-30 21:42:17', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG280', 'LH280', 1, 'Rất thất vọng.', 'Chờ đợi quá lâu', '2025-01-27 03:16:56', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG281', 'LH281', 1, 'Dịch vụ quá tệ.', 'Chờ đợi quá lâu', '2025-07-20 02:57:16', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG282', 'LH282', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-02-21 21:39:53', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG283', 'LH283', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-04-03 13:58:55', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG284', 'LH284', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2025-05-30 08:36:01', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG285', 'LH285', 3, 'Chất lượng tạm ổn.', NULL, '2025-02-22 05:11:12', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG286', 'LH286', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-06-02 04:03:05', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG287', 'LH287', 3, 'Chất lượng tạm ổn.', NULL, '2025-10-01 02:31:57', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG001', 'LH001', 1, 'Dịch vụ quá tệ.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-11-22 22:44:57', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG003', 'LH003', 5, 'Bệnh viện sạch sẽ hiện đại.', NULL, '2025-12-19 20:33:26', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG004', 'LH004', 2, 'Thái độ nhân viên chưa tốt.', 'Chờ đợi quá lâu', '2025-05-24 21:16:22', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG005', 'LH005', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-01-27 16:58:54', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG006', 'LH006', 1, 'Sẽ không quay lại.', 'Chờ đợi quá lâu', '2025-10-17 01:36:42', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG007', 'LH007', 5, 'Tuyệt vời!', NULL, '2025-05-18 01:29:07', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG008', 'LH008', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-11-03 17:23:57', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG009', 'LH009', 1, 'Dịch vụ quá tệ.', 'Bác sĩ khám quá nhanh', '2025-12-18 05:42:26', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG010', 'LH010', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-08-04 18:43:09', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG011', 'LH011', 1, 'Sẽ không quay lại.', 'Chờ đợi quá lâu', '2025-05-26 03:27:43', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG012', 'LH012', 2, 'Không hài lòng lắm.', 'Bác sĩ khám quá nhanh', '2025-12-04 13:56:13', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG013', 'LH013', 3, 'Chất lượng tạm ổn.', NULL, '2026-03-28 10:37:57', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG014', 'LH014', 4, 'Hài lòng với trải nghiệm.', NULL, '2026-03-10 08:42:05', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG015', 'LH015', 2, 'Thái độ nhân viên chưa tốt.', 'Bác sĩ khám quá nhanh', '2025-05-04 18:04:54', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG016', 'LH016', 1, 'Dịch vụ quá tệ.', 'Bác sĩ khám quá nhanh', '2025-07-07 12:12:40', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG017', 'LH017', 2, 'Thái độ nhân viên chưa tốt.', 'Vệ sinh phòng khám không đảm bảo', '2025-07-16 18:47:22', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG018', 'LH018', 4, 'Bác sĩ tận tâm.', NULL, '2025-11-29 08:36:32', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG019', 'LH019', 3, 'Chất lượng tạm ổn.', NULL, '2025-05-16 11:24:17', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG020', 'LH020', 3, 'Chất lượng tạm ổn.', NULL, '2025-06-08 17:16:23', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG021', 'LH021', 2, 'Thái độ nhân viên chưa tốt.', 'Vệ sinh phòng khám không đảm bảo', '2026-02-10 17:16:59', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG022', 'LH022', 4, 'Dịch vụ tốt.', NULL, '2026-01-31 19:39:29', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG023', 'LH023', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-12-29 20:07:20', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG024', 'LH024', 3, 'Phòng khám hơi đông.', NULL, '2025-08-22 06:48:53', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG025', 'LH025', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-07-03 13:07:20', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG026', 'LH026', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-04-08 08:32:54', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG027', 'LH027', 2, 'Không hài lòng lắm.', 'Chờ đợi quá lâu', '2025-06-30 22:04:51', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG028', 'LH028', 2, 'Thái độ nhân viên chưa tốt.', 'Chờ đợi quá lâu', '2026-02-13 12:26:56', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG029', 'LH029', 2, 'Không hài lòng lắm.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-02-22 14:25:51', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG030', 'LH030', 1, 'Rất thất vọng.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-07-30 09:32:32', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG031', 'LH031', 3, 'Phòng khám hơi đông.', NULL, '2025-02-20 01:33:30', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG032', 'LH032', 4, 'Dịch vụ tốt.', NULL, '2025-05-01 23:29:11', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG033', 'LH033', 2, 'Thái độ nhân viên chưa tốt.', 'Vệ sinh phòng khám không đảm bảo', '2026-02-25 20:18:11', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG034', 'LH034', 3, 'Chất lượng tạm ổn.', NULL, '2025-01-05 07:21:48', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG288', 'LH288', 3, 'Phòng khám hơi đông.', NULL, '2025-06-13 18:28:12', 'Trung tính');
INSERT INTO public.danh_gia VALUES ('DG289', 'LH289', 1, 'Rất thất vọng.', 'Chờ đợi quá lâu', '2025-02-13 17:01:48', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG206', 'LH206', 5, 'Tuyệt vời!', NULL, '2025-05-01 10:57:57', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG290', 'LH290', 1, 'Rất thất vọng.', 'Chờ đợi quá lâu', '2025-12-17 00:50:51', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG291', 'LH291', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-01-17 05:29:28', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG292', 'LH292', 4, 'Bác sĩ tận tâm.', NULL, '2025-11-15 01:15:12', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG293', 'LH293', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-08-05 02:18:37', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG294', 'LH294', 1, 'Sẽ không quay lại.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-01-04 08:50:45', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG295', 'LH295', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2025-10-09 06:29:53', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG296', 'LH296', 4, 'Bác sĩ tận tâm.', NULL, '2026-03-15 11:37:01', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG297', 'LH297', 2, 'Thái độ nhân viên chưa tốt.', 'Thái độ nhân viên thiếu chuyên nghiệp', '2026-01-27 18:40:58', 'Tiêu cực');
INSERT INTO public.danh_gia VALUES ('DG298', 'LH298', 5, 'Rất hài lòng với bác sĩ.', NULL, '2025-05-10 14:06:11', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG299', 'LH299', 4, 'Hài lòng với trải nghiệm.', NULL, '2025-12-18 05:02:33', 'Tích cực');
INSERT INTO public.danh_gia VALUES ('DG300', 'LH300', 4, 'Bác sĩ tận tâm.', NULL, '2026-03-27 04:02:01', 'Tích cực');


--
-- TOC entry 5077 (class 0 OID 17117)
-- Dependencies: 222
-- Data for Name: dich_vu; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.dich_vu VALUES ('DV001', 'Khám nội tổng quát tại nhà', 'Bác sĩ thăm khám - đo sinh hiệu và tư vấn sức khỏe', 350000.00, 30, 'Khám bệnh', 'Bác sĩ');
INSERT INTO public.dich_vu VALUES ('DV002', 'Khám tim mạch chuyên sâu', 'Bác sĩ khám - đo điện tim và kiểm tra huyết áp', 500000.00, 45, 'Khám bệnh', 'Bác sĩ');
INSERT INTO public.dich_vu VALUES ('DV003', 'Tiêm thuốc bắp / tĩnh mạch', 'Điều dưỡng thực hiện tiêm thuốc theo toa bác sĩ', 100000.00, 15, 'Điều trị', 'Điều dưỡng');
INSERT INTO public.dich_vu VALUES ('DV004', 'Truyền dịch đạm tại nhà', 'Điều dưỡng thực hiện truyền dịch và vitamin theo chỉ định', 250000.00, 120, 'Điều trị', 'Điều dưỡng');
INSERT INTO public.dich_vu VALUES ('DV005', 'Thay băng cắt chỉ vết thương', 'Vệ sinh - sát khuẩn và thay băng vết thương hở', 150000.00, 20, 'Chăm sóc', 'Điều dưỡng');
INSERT INTO public.dich_vu VALUES ('DV006', 'Lấy mẫu xét nghiệm máu tận nơi', 'KTV lấy mẫu máu - nước tiểu và gửi đến phòng Lab', 120000.00, 15, 'Xét nghiệm', 'Kỹ thuật viên');
INSERT INTO public.dich_vu VALUES ('DV007', 'Vật lý trị liệu phục hồi chức năng', 'KTV hướng dẫn và tập phục hồi chức năng cho bệnh nhân', 300000.00, 60, 'Điều trị', 'Kỹ thuật viên');
INSERT INTO public.dich_vu VALUES ('DV008', 'Tắm bé sơ sinh chuẩn y tế', 'Vệ sinh - tắm rửa - massage và chăm sóc rốn cho trẻ sơ sinh', 150000.00, 45, 'Chăm sóc', 'Hộ sinh');
INSERT INTO public.dich_vu VALUES ('DV009', 'Chăm sóc vết mổ cho mẹ sau sinh', 'Kiểm tra vết mổ - vệ sinh và tư vấn dinh dưỡng cho mẹ', 200000.00, 60, 'Chăm sóc', 'Hộ sinh');
INSERT INTO public.dich_vu VALUES ('DV010', 'Đặt ống thông dạ dày (Sonde)', 'Điều dưỡng đặt sonde dạ dày cho bệnh nhân không tự ăn', 250000.00, 30, 'Điều trị', 'Điều dưỡng');


--
-- TOC entry 5081 (class 0 OID 17191)
-- Dependencies: 226
-- Data for Name: hoa_don; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.hoa_don VALUES ('HD-LH001', 'LH001', 120000.00, 160000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH002', 'LH002', 150000.00, 800000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH003', 'LH003', 120000.00, 850000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH004', 'LH004', 500000.00, 30000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH005', 'LH005', 250000.00, 1120000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH006', 'LH006', 120000.00, 285000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH007', 'LH007', 100000.00, 850000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH008', 'LH008', 500000.00, 850000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH009', 'LH009', 100000.00, 12000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH010', 'LH010', 150000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH011', 'LH011', 250000.00, 3250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH012', 'LH012', 150000.00, 12000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH013', 'LH013', 120000.00, 30000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH014', 'LH014', 100000.00, 1100000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH015', 'LH015', 100000.00, 880000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH016', 'LH016', 250000.00, 240000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH017', 'LH017', 100000.00, 750000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH018', 'LH018', 500000.00, 160000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH019', 'LH019', 500000.00, 260000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH020', 'LH020', 250000.00, 240000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH021', 'LH021', 500000.00, 135000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH022', 'LH022', 350000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH023', 'LH023', 150000.00, 250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH024', 'LH024', 250000.00, 150000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH025', 'LH025', 250000.00, 3000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH026', 'LH026', 500000.00, 900000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH027', 'LH027', 100000.00, 750000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH028', 'LH028', 150000.00, 450000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH029', 'LH029', 250000.00, 95000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH030', 'LH030', 300000.00, 3600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH031', 'LH031', 100000.00, 7500000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH032', 'LH032', 144000.00, 660000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH033', 'LH033', 500000.00, 850000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH034', 'LH034', 120000.00, 85000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH035', 'LH035', 500000.00, 600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH036', 'LH036', 120000.00, 440000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH037', 'LH037', 200000.00, 20000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH038', 'LH038', 500000.00, 475000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH039', 'LH039', 250000.00, 310000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH040', 'LH040', 150000.00, 310000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH041', 'LH041', 250000.00, 40000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH042', 'LH042', 350000.00, 480000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH043', 'LH043', 150000.00, 1500000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH044', 'LH044', 150000.00, 320000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH045', 'LH045', 300000.00, 2550000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH046', 'LH046', 120000.00, 6000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH047', 'LH047', 150000.00, 85000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH048', 'LH048', 350000.00, 540000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH049', 'LH049', 250000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH050', 'LH050', 300000.00, 40000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH051', 'LH051', 250000.00, 105000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH052', 'LH052', 100000.00, 60000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH053', 'LH053', 350000.00, 130000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH054', 'LH054', 250000.00, 1500000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH055', 'LH055', 200000.00, 70000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH056', 'LH056', 250000.00, 1000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH057', 'LH057', 120000.00, 30000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH058', 'LH058', 150000.00, 475000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH059', 'LH059', 350000.00, 160000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH060', 'LH060', 120000.00, 150000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH061', 'LH061', 300000.00, 880000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH062', 'LH062', 500000.00, 30000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH063', 'LH063', 300000.00, 620000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH064', 'LH064', 350000.00, 480000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH065', 'LH065', 250000.00, 255000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH066', 'LH066', 500000.00, 600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH067', 'LH067', 150000.00, 30000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH068', 'LH068', 250000.00, 220000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH069', 'LH069', 300000.00, 270000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH070', 'LH070', 150000.00, 660000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH071', 'LH071', 200000.00, 600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH072', 'LH072', 300000.00, 600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH073', 'LH073', 150000.00, 360000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH074', 'LH074', 100000.00, 620000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH075', 'LH075', 200000.00, 1700000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH076', 'LH076', 120000.00, 750000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH077', 'LH077', 360000.00, 1000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH078', 'LH078', 120000.00, 60000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH079', 'LH079', 100000.00, 1300000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH080', 'LH080', 300000.00, 1700000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH081', 'LH081', 250000.00, 960000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH082', 'LH082', 250000.00, 400000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH083', 'LH083', 200000.00, 195000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH084', 'LH084', 120000.00, 1700000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH085', 'LH085', 200000.00, 6000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH086', 'LH086', 250000.00, 640000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH087', 'LH087', 350000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH088', 'LH088', 150000.00, 440000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH089', 'LH089', 150000.00, 6000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH090', 'LH090', 500000.00, 880000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH091', 'LH091', 150000.00, 1500000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH092', 'LH092', 100000.00, 1550000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH093', 'LH093', 100000.00, 3000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH094', 'LH094', 100000.00, 1000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH095', 'LH095', 250000.00, 9000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH096', 'LH096', 300000.00, 170000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH097', 'LH097', 100000.00, 95000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH098', 'LH098', 150000.00, 880000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH099', 'LH099', 200000.00, 1550000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH100', 'LH100', 200000.00, 360000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH101', 'LH101', 200000.00, 80000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH102', 'LH102', 500000.00, 255000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH103', 'LH103', 200000.00, 300000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH104', 'LH104', 300000.00, 1100000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH105', 'LH105', 150000.00, 440000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH106', 'LH106', 200000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH107', 'LH107', 200000.00, 135000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH108', 'LH108', 120000.00, 2550000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH109', 'LH109', 150000.00, 65000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH110', 'LH110', 150000.00, 560000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH111', 'LH111', 150000.00, 9000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH112', 'LH112', 200000.00, 12000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH113', 'LH113', 150000.00, 2600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH114', 'LH114', 180000.00, 135000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH115', 'LH115', 150000.00, 1500000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH116', 'LH116', 150000.00, 250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH117', 'LH117', 500000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH118', 'LH118', 120000.00, 800000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH119', 'LH119', 350000.00, 3400000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH120', 'LH120', 300000.00, 160000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH121', 'LH121', 250000.00, 1120000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH122', 'LH122', 250000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH123', 'LH123', 250000.00, 60000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH124', 'LH124', 350000.00, 30000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH125', 'LH125', 250000.00, 1200000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH126', 'LH126', 200000.00, 100000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH127', 'LH127', 120000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH128', 'LH128', 300000.00, 120000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH129', 'LH129', 600000.00, 360000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH130', 'LH130', 250000.00, 12000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH131', 'LH131', 150000.00, 1000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH132', 'LH132', 200000.00, 30000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH133', 'LH133', 200000.00, 1300000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH134', 'LH134', 200000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH135', 'LH135', 120000.00, 6000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH136', 'LH136', 300000.00, 1280000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH137', 'LH137', 350000.00, 65000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH138', 'LH138', 100000.00, 4250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH139', 'LH139', 250000.00, 440000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH140', 'LH140', 250000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH141', 'LH141', 200000.00, 4500000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH142', 'LH142', 150000.00, 200000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH143', 'LH143', 350000.00, 380000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH144', 'LH144', 120000.00, 60000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH145', 'LH145', 300000.00, 30000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH146', 'LH146', 120000.00, 60000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH147', 'LH147', 200000.00, 240000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH148', 'LH148', 250000.00, 600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH149', 'LH149', 350000.00, 4250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH150', 'LH150', 250000.00, 285000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH151', 'LH151', 300000.00, 1280000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH152', 'LH152', 250000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH153', 'LH153', 150000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH154', 'LH154', 150000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH155', 'LH155', 150000.00, 930000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH156', 'LH156', 500000.00, 3600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH157', 'LH157', 250000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH158', 'LH158', 150000.00, 340000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH159', 'LH159', 350000.00, 160000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH160', 'LH160', 100000.00, 880000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH161', 'LH161', 500000.00, 170000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH162', 'LH162', 150000.00, 930000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH163', 'LH163', 500000.00, 60000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH164', 'LH164', 250000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH165', 'LH165', 150000.00, 1000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH166', 'LH166', 180000.00, 750000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH167', 'LH167', 100000.00, 1280000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH168', 'LH168', 350000.00, 900000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH169', 'LH169', 150000.00, 3400000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH170', 'LH170', 300000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH171', 'LH171', 100000.00, 1250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH172', 'LH172', 100000.00, 650000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH173', 'LH173', 420000.00, 1100000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH174', 'LH174', 350000.00, 90000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH175', 'LH175', 150000.00, 240000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH176', 'LH176', 300000.00, 750000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH177', 'LH177', 250000.00, 1950000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH178', 'LH178', 120000.00, 60000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH179', 'LH179', 150000.00, 360000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH180', 'LH180', 250000.00, 7500000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH181', 'LH181', 120000.00, 340000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH182', 'LH182', 150000.00, 4500000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH183', 'LH183', 250000.00, 190000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH184', 'LH184', 100000.00, 405000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH185', 'LH185', 100000.00, 450000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH186', 'LH186', 350000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH187', 'LH187', 300000.00, 4250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH188', 'LH188', 300000.00, 85000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH189', 'LH189', 150000.00, 540000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH190', 'LH190', 150000.00, 150000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH191', 'LH191', 250000.00, 1600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH192', 'LH192', 150000.00, 300000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH193', 'LH193', 250000.00, 1950000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH194', 'LH194', 120000.00, 220000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH195', 'LH195', 350000.00, 150000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH196', 'LH196', 100000.00, 1300000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH197', 'LH197', 120000.00, 300000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH198', 'LH198', 300000.00, 120000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH199', 'LH199', 150000.00, 135000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH200', 'LH200', 200000.00, 220000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH201', 'LH201', 350000.00, 540000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH202', 'LH202', 150000.00, 640000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH203', 'LH203', 100000.00, 400000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH204', 'LH204', 150000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH205', 'LH205', 150000.00, 450000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH206', 'LH206', 300000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH207', 'LH207', 120000.00, 960000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH208', 'LH208', 120000.00, 180000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH209', 'LH209', 150000.00, 750000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH210', 'LH210', 500000.00, 340000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH211', 'LH211', 500000.00, 6000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH212', 'LH212', 120000.00, 650000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH213', 'LH213', 250000.00, 620000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH214', 'LH214', 150000.00, 225000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH215', 'LH215', 250000.00, 30000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH216', 'LH216', 250000.00, 220000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH217', 'LH217', 350000.00, 1550000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH218', 'LH218', 300000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH219', 'LH219', 100000.00, 1200000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH220', 'LH220', 150000.00, 450000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH221', 'LH221', 500000.00, 1700000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH222', 'LH222', 250000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH223', 'LH223', 200000.00, 440000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH224', 'LH224', 250000.00, 330000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH225', 'LH225', 144000.00, 40000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH226', 'LH226', 240000.00, 360000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH227', 'LH227', 100000.00, 540000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH228', 'LH228', 100000.00, 80000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH229', 'LH229', 250000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH230', 'LH230', 100000.00, 480000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH231', 'LH231', 250000.00, 200000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH232', 'LH232', 300000.00, 285000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH233', 'LH233', 200000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH234', 'LH234', 150000.00, 200000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH235', 'LH235', 250000.00, 450000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH236', 'LH236', 120000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH237', 'LH237', 350000.00, 4250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH238', 'LH238', 350000.00, 1120000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH239', 'LH239', 500000.00, 1000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH240', 'LH240', 100000.00, 95000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH241', 'LH241', 150000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH242', 'LH242', 420000.00, 120000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH243', 'LH243', 150000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH244', 'LH244', 250000.00, 540000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH245', 'LH245', 250000.00, 480000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH246', 'LH246', 500000.00, 85000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH247', 'LH247', 100000.00, 600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH248', 'LH248', 200000.00, 4500000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH249', 'LH249', 300000.00, 3250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH250', 'LH250', 120000.00, 15000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH251', 'LH251', 250000.00, 60000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH252', 'LH252', 100000.00, 450000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH253', 'LH253', 120000.00, 405000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH254', 'LH254', 350000.00, 200000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH255', 'LH255', 150000.00, 3400000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH256', 'LH256', 500000.00, 880000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH257', 'LH257', 150000.00, 6000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH258', 'LH258', 250000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH259', 'LH259', 200000.00, 120000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH260', 'LH260', 250000.00, 6000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH261', 'LH261', 150000.00, 195000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH262', 'LH262', 420000.00, 320000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH263', 'LH263', 250000.00, 850000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH264', 'LH264', 500000.00, 600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH265', 'LH265', 100000.00, 750000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH266', 'LH266', 200000.00, 2550000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH267', 'LH267', 300000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH268', 'LH268', 120000.00, 85000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH269', 'LH269', 300000.00, 880000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH270', 'LH270', 250000.00, 70000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH271', 'LH271', 150000.00, 360000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH272', 'LH272', 120000.00, 330000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH273', 'LH273', 200000.00, 2400000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH274', 'LH274', 150000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH275', 'LH275', 200000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH276', 'LH276', 150000.00, 180000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH277', 'LH277', 350000.00, 300000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH278', 'LH278', 100000.00, 1240000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH279', 'LH279', 300000.00, 640000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH280', 'LH280', 250000.00, 405000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH281', 'LH281', 150000.00, 1400000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH282', 'LH282', 250000.00, 6000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH283', 'LH283', 250000.00, 120000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH284', 'LH284', 150000.00, 250000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH285', 'LH285', 350000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH286', 'LH286', 120000.00, 600000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH287', 'LH287', 500000.00, 9000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH288', 'LH288', 100000.00, 480000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH289', 'LH289', 100000.00, 45000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH290', 'LH290', 240000.00, 85000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH291', 'LH291', 300000.00, 1200000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH292', 'LH292', 120000.00, 9000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH293', 'LH293', 350000.00, 75000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH294', 'LH294', 350000.00, 480000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH295', 'LH295', 150000.00, 4800000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH296', 'LH296', 150000.00, 650000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH297', 'LH297', 500000.00, 6000000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH298', 'LH298', 150000.00, 640000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH299', 'LH299', 300000.00, 180000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HD-LH300', 'LH300', 350000.00, 480000.00, 0.00, DEFAULT, '2026-04-16 17:49:10.345154', NULL, 'Chưa thanh toán');
INSERT INTO public.hoa_don VALUES ('HDKQ301', 'LH301', 500000.00, 0.00, 0.00, DEFAULT, '2026-05-16 16:52:52.64988', NULL, 'Chưa thanh toán');


--
-- TOC entry 5084 (class 0 OID 17246)
-- Dependencies: 229
-- Data for Name: ket_qua_kham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.ket_qua_kham VALUES ('KQ002', 'LH002', 'Rối loạn mỡ máu', '119/74', 86, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ003', 'LH003', 'Viêm phế quản mạn tính', '125/73', 70, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ004', 'LH004', 'sốt siêu vi', '115/76', 81, 37.9, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ005', 'LH005', 'Trầm cảm', '122/83', 85, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ006', 'LH006', 'Thiếu máu', '122/76', 75, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ007', 'LH007', 'Viêm phế quản mạn tính', '111/79', 60, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ008', 'LH008', 'Viêm phế quản mạn tính', '119/78', 74, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ009', 'LH009', 'Suy thận mạn', '130/87', 67, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ010', 'LH010', 'sốt siêu vi', '124/74', 87, 37.1, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ011', 'LH011', 'Bệnh tim mạch', '149/97', 131, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ012', 'LH012', 'sốt xuất huyết', '122/84', 75, 38.4, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ013', 'LH013', 'Dị ứng thời tiết', '125/70', 81, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ014', 'LH014', 'Loãng xương', '116/83', 76, 36.3, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ015', 'LH015', 'Loãng xương', '117/77', 72, 36.4, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ016', 'LH016', 'Ung thư đại tràng', '123/85', 63, 36.5, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ017', 'LH017', 'Tiểu đường tuýp 1', '136/85', 62, 36.3, 'Xét nghiệm đường huyết', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ018', 'LH018', 'Dị ứng thực phẩm', '118/70', 68, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ019', 'LH019', 'Ung thư vú', '111/76', 86, 36.3, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ020', 'LH020', 'Ung thư đại tràng', '115/71', 87, 36.5, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ021', 'LH021', 'Thoái hóa khớp', '112/71', 71, 36.5, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ022', 'LH022', 'sốt siêu vi', '124/83', 78, 38.9, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ023', 'LH023', 'Tiểu đường tuýp 1', '137/89', 79, 36.9, 'Xét nghiệm đường huyết', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ024', 'LH024', 'Không có', '125/78', 63, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ025', 'LH025', 'Suy thận mạn', '137/80', 90, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ026', 'LH026', 'Suy tim', '147/94', 103, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ027', 'LH027', 'Tiểu đường tuýp 1', '131/85', 89, 36.7, 'Xét nghiệm đường huyết', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ028', 'LH028', 'Viêm gan B', '117/73', 61, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ029', 'LH029', 'Thiếu máu', '114/81', 79, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ030', 'LH030', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', '123/74', 83, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ031', 'LH031', 'Ung thư phổi', '112/82', 72, 36.6, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ032', 'LH032', 'Loãng xương', '120/77', 71, 36.3, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ033', 'LH033', 'Viêm phế quản mạn tính', '124/82', 82, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ034', 'LH034', 'Hen suyễn', '117/82', 73, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ035', 'LH035', 'Tiểu đường tuýp 2', '136/85', 69, 36.8, 'Xét nghiệm đường huyết', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ036', 'LH036', 'Gout', '114/72', 89, 36.7, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ037', 'LH037', 'Dị ứng thuốc', '124/73', 70, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ038', 'LH038', 'Thiếu máu', '121/70', 63, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ039', 'LH039', 'Mất ngủ kéo dài', '118/85', 75, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ040', 'LH040', 'Mất ngủ kéo dài', '114/83', 67, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ041', 'LH041', 'Dị ứng thực phẩm', '123/74', 60, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ042', 'LH042', 'Rối loạn mỡ máu', '125/76', 74, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ043', 'LH043', 'Ung thư phổi', '110/82', 80, 36.7, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ044', 'LH044', 'Sỏi thận', '118/74', 84, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ045', 'LH045', 'Viêm phế quản mạn tính', '125/79', 75, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ272', 'LH272', 'Gout', '115/85', 65, 36.5, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ046', 'LH046', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', '115/72', 84, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ047', 'LH047', 'Ung thư gan', '113/73', 68, 36.3, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ048', 'LH048', 'Rối loạn lo âu', '125/79', 73, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ049', 'LH049', 'sốt siêu vi', '121/83', 78, 38.9, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ050', 'LH050', 'Dị ứng thuốc', '116/82', 74, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ051', 'LH051', 'Tăng huyết áp', '149/93', 60, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ052', 'LH052', 'Dị ứng thời tiết', '124/76', 73, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ053', 'LH053', 'Ung thư vú', '112/80', 87, 36.1, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ054', 'LH054', 'Ung thư phổi', '122/76', 78, 36.4, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ055', 'LH055', 'Tăng huyết áp', '156/94', 85, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ056', 'LH056', 'Tiểu đường tuýp 1', '132/81', 71, 36.3, 'Xét nghiệm đường huyết', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ057', 'LH057', 'Dị ứng thời tiết', '112/84', 77, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ058', 'LH058', 'Thiếu máu', '120/80', 85, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ059', 'LH059', 'Rối loạn mỡ máu', '124/85', 69, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ060', 'LH060', 'Viêm gan C', '114/72', 86, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ061', 'LH061', 'Loãng xương', '117/85', 63, 36.3, 'Chụp X-quang', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ062', 'LH062', 'sốt siêu vi', '116/83', 88, 38.7, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ063', 'LH063', 'Mất ngủ kéo dài', '118/78', 75, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ064', 'LH064', 'Tiểu đường tuýp 2', '133/86', 81, 36.6, 'Xét nghiệm đường huyết', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ065', 'LH065', 'Ung thư gan', '112/71', 67, 36.7, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ066', 'LH066', 'Viêm gan C', '113/81', 86, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ067', 'LH067', 'Dị ứng thời tiết', '116/77', 68, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ068', 'LH068', 'Gout', '114/79', 84, 36.5, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ069', 'LH069', 'Rối loạn lo âu', '125/82', 78, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ070', 'LH070', 'Loãng xương', '115/84', 73, 36.8, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ071', 'LH071', 'Không có', '123/80', 76, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ072', 'LH072', 'Ung thư đại tràng', '114/85', 87, 36.6, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ073', 'LH073', 'Suy tim', '155/99', 111, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ074', 'LH074', 'Mất ngủ kéo dài', '118/80', 85, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ075', 'LH075', 'Viêm phế quản mạn tính', '125/85', 60, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ076', 'LH076', 'Viêm gan C', '122/78', 89, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ077', 'LH077', 'Xơ gan', '113/85', 72, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ078', 'LH078', 'sốt siêu vi', '111/78', 67, 39.5, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'CẢNH BÁO AI: Nguy cơ sốt co giật.', 0.85);
INSERT INTO public.ket_qua_kham VALUES ('KQ079', 'LH079', 'Bệnh tim mạch', '160/99', 123, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ080', 'LH080', 'Viêm phế quản mạn tính', '113/78', 65, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ081', 'LH081', 'Sỏi thận', '125/78', 64, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ082', 'LH082', 'Xơ gan', '119/72', 62, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ083', 'LH083', 'Ung thư vú', '114/83', 60, 36.1, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ084', 'LH084', 'Viêm phế quản mạn tính', '111/72', 61, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ085', 'LH085', 'Ung thư phổi', '118/73', 73, 36.4, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ086', 'LH086', 'Rối loạn mỡ máu', '115/80', 73, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ087', 'LH087', 'Dị ứng thời tiết', '112/72', 76, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ088', 'LH088', 'Gout', '122/71', 62, 36.4, 'Chụp X-quang', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ089', 'LH089', 'Suy thận mạn', '133/84', 65, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ090', 'LH090', 'Loãng xương', '123/82', 81, 36.7, 'Chụp X-quang', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ091', 'LH091', 'Ung thư phổi', '114/74', 79, 36.2, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ092', 'LH092', 'Mất ngủ kéo dài', '125/80', 81, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ093', 'LH093', 'sốt xuất huyết', '121/78', 83, 38.5, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ094', 'LH094', 'Xơ gan', '110/84', 64, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ095', 'LH095', 'Suy thận mạn', '133/84', 72, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ096', 'LH096', 'Hen suyễn', '121/85', 83, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ097', 'LH097', 'Thiếu máu', '116/77', 66, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ098', 'LH098', 'Loãng xương', '116/74', 65, 36.8, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ099', 'LH099', 'Mất ngủ kéo dài', '114/71', 61, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ100', 'LH100', 'Suy tim', '142/97', 133, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ101', 'LH101', 'Dị ứng thuốc', '117/85', 72, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ102', 'LH102', 'Ung thư gan', '120/73', 76, 36.1, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ103', 'LH103', 'Không có', '112/71', 80, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ104', 'LH104', 'Loãng xương', '118/84', 74, 36.4, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ105', 'LH105', 'Gout', '112/85', 65, 36.2, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ106', 'LH106', 'Thoái hóa khớp', '114/75', 60, 36.3, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ107', 'LH107', 'Thoái hóa khớp', '119/81', 71, 36.3, 'Chụp X-quang', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ108', 'LH108', 'Viêm phế quản mạn tính', '112/81', 74, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ109', 'LH109', 'Ung thư vú', '111/74', 90, 36.7, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ110', 'LH110', 'Trầm cảm', '123/73', 67, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ111', 'LH111', 'sốt xuất huyết', '117/70', 71, 38.6, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ112', 'LH112', 'Suy thận mạn', '135/89', 83, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ113', 'LH113', 'Bệnh tim mạch', '147/94', 137, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ114', 'LH114', 'Thoái hóa khớp', '124/70', 81, 36.2, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ115', 'LH115', 'Ung thư phổi', '120/75', 90, 36.6, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ116', 'LH116', 'Tiểu đường tuýp 1', '137/85', 65, 36.8, 'Xét nghiệm đường huyết', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ117', 'LH117', 'sốt siêu vi', '122/81', 82, 39.0, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ118', 'LH118', 'Xơ gan', '122/71', 84, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ119', 'LH119', 'Viêm phế quản mạn tính', '122/83', 83, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ120', 'LH120', 'Rối loạn mỡ máu', '119/73', 84, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ121', 'LH121', 'Trầm cảm', '124/82', 80, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ122', 'LH122', 'sốt siêu vi', '122/80', 70, 38.5, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ123', 'LH123', 'sốt siêu vi', '118/71', 76, 37.2, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ124', 'LH124', 'Dị ứng thời tiết', '120/78', 79, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ125', 'LH125', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', '117/83', 63, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ126', 'LH126', 'Dị ứng thuốc', '116/71', 80, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ127', 'LH127', 'sốt siêu vi', '110/73', 60, 37.8, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ128', 'LH128', 'Dị ứng thực phẩm', '119/75', 86, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ129', 'LH129', 'Ung thư đại tràng', '116/74', 75, 36.7, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ130', 'LH130', 'sốt xuất huyết', '114/79', 73, 39.1, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'CẢNH BÁO AI: Nguy cơ sốt co giật.', 0.85);
INSERT INTO public.ket_qua_kham VALUES ('KQ131', 'LH131', 'Xơ gan', '115/85', 69, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ132', 'LH132', 'Dị ứng thời tiết', '113/78', 83, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ133', 'LH133', 'Bệnh tim mạch', '152/98', 138, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ134', 'LH134', 'sốt xuất huyết', '122/85', 87, 39.1, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'CẢNH BÁO AI: Nguy cơ sốt co giật.', 0.85);
INSERT INTO public.ket_qua_kham VALUES ('KQ135', 'LH135', 'Suy thận mạn', '135/88', 87, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ136', 'LH136', 'Sỏi thận', '114/81', 60, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ137', 'LH137', 'Ung thư vú', '123/84', 87, 36.8, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ138', 'LH138', 'Viêm phế quản mạn tính', '121/72', 83, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ139', 'LH139', 'Gout', '121/80', 73, 36.6, 'Chụp X-quang', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ140', 'LH140', 'Dị ứng thời tiết', '110/83', 80, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ141', 'LH141', 'Ung thư phổi', '112/77', 73, 36.5, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ142', 'LH142', 'Xơ gan', '112/76', 68, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ143', 'LH143', 'Thiếu máu', '120/83', 67, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ144', 'LH144', 'Dị ứng thời tiết', '116/71', 63, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ145', 'LH145', 'Dị ứng thời tiết', '114/72', 83, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ146', 'LH146', 'Dị ứng thời tiết', '122/85', 79, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ147', 'LH147', 'Ung thư đại tràng', '118/78', 88, 36.2, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ148', 'LH148', 'Viêm gan C', '125/80', 70, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ149', 'LH149', 'Viêm phế quản mạn tính', '115/82', 78, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ150', 'LH150', 'Thiếu máu', '117/83', 70, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ151', 'LH151', 'Sỏi thận', '113/79', 85, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ152', 'LH152', 'sốt siêu vi', '119/77', 66, 37.2, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ153', 'LH153', 'Thoái hóa khớp', '125/81', 70, 36.7, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ154', 'LH154', 'sốt xuất huyết', '121/71', 86, 39.4, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'CẢNH BÁO AI: Nguy cơ sốt co giật.', 0.85);
INSERT INTO public.ket_qua_kham VALUES ('KQ155', 'LH155', 'Mất ngủ kéo dài', '116/85', 71, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ156', 'LH156', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', '125/74', 60, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ157', 'LH157', 'sốt siêu vi', '124/75', 74, 37.8, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ158', 'LH158', 'Hen suyễn', '111/82', 73, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ159', 'LH159', 'Rối loạn mỡ máu', '112/79', 71, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ160', 'LH160', 'Loãng xương', '123/84', 68, 36.3, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ161', 'LH161', 'Ung thư gan', '110/72', 64, 36.3, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ162', 'LH162', 'Mất ngủ kéo dài', '114/82', 90, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ163', 'LH163', 'sốt siêu vi', '111/70', 87, 37.3, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ164', 'LH164', 'Dị ứng thời tiết', '115/82', 80, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ165', 'LH165', 'Xơ gan', '110/72', 63, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ166', 'LH166', 'Không có', '122/80', 60, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ167', 'LH167', 'Sỏi thận', '123/75', 90, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ168', 'LH168', 'Suy tim', '156/94', 116, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ169', 'LH169', 'Viêm phế quản mạn tính', '115/70', 85, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ170', 'LH170', 'Dị ứng thời tiết', '125/82', 79, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ171', 'LH171', 'Tiểu đường tuýp 1', '136/89', 69, 36.4, 'Xét nghiệm đường huyết', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ172', 'LH172', 'Bệnh tim mạch', '140/91', 145, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ173', 'LH173', 'Loãng xương', '110/72', 80, 36.3, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ174', 'LH174', 'Thoái hóa khớp', '119/80', 89, 36.1, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ175', 'LH175', 'Ung thư đại tràng', '124/84', 60, 36.9, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ176', 'LH176', 'Viêm gan C', '111/80', 86, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ177', 'LH177', 'Bệnh tim mạch', '145/99', 138, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ178', 'LH178', 'Dị ứng thời tiết', '117/80', 72, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ179', 'LH179', 'Suy tim', '147/95', 117, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ180', 'LH180', 'Ung thư phổi', '112/81', 80, 36.1, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ001', 'LH001', 'Dị ứng thực phẩm', '114/78', 85, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ181', 'LH181', 'Ung thư gan', '120/75', 77, 36.9, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ182', 'LH182', 'Ung thư phổi', '113/76', 68, 36.8, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ183', 'LH183', 'Thiếu máu', '114/82', 80, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ184', 'LH184', 'Rối loạn lo âu', '125/73', 67, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ185', 'LH185', 'Không có', '120/72', 88, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ186', 'LH186', 'Thoái hóa khớp', '114/73', 65, 36.8, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ187', 'LH187', 'Viêm phế quản mạn tính', '114/81', 66, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ188', 'LH188', 'Ung thư gan', '111/83', 65, 36.7, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ189', 'LH189', 'Rối loạn lo âu', '119/78', 78, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ190', 'LH190', 'Viêm gan C', '117/75', 66, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ191', 'LH191', 'Sỏi thận', '125/75', 63, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ192', 'LH192', 'Viêm gan C', '114/84', 64, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ193', 'LH193', 'Bệnh tim mạch', '151/91', 142, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ194', 'LH194', 'Gout', '113/76', 71, 36.2, 'Chụp X-quang', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ195', 'LH195', 'Viêm gan C', '121/78', 88, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ196', 'LH196', 'Bệnh tim mạch', '142/94', 137, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ197', 'LH197', 'Không có', '113/72', 70, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ198', 'LH198', 'Ung thư đại tràng', '115/84', 66, 36.8, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ199', 'LH199', 'Rối loạn lo âu', '113/80', 90, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ200', 'LH200', 'Gout', '123/73', 73, 36.4, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ201', 'LH201', 'Rối loạn lo âu', '116/83', 84, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ202', 'LH202', 'Sỏi thận', '111/70', 90, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ203', 'LH203', 'Xơ gan', '115/78', 83, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ204', 'LH204', 'Dị ứng thời tiết', '120/82', 70, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ205', 'LH205', 'Không có', '122/75', 78, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ206', 'LH206', 'Thoái hóa khớp', '112/74', 86, 36.6, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ207', 'LH207', 'Sỏi thận', '121/73', 66, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ208', 'LH208', 'Thoái hóa khớp', '124/84', 65, 36.1, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ209', 'LH209', 'Viêm gan C', '118/81', 72, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ210', 'LH210', 'Ung thư gan', '125/78', 62, 36.3, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ211', 'LH211', 'Ung thư phổi', '112/83', 83, 36.3, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ212', 'LH212', 'Bệnh tim mạch', '142/99', 116, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ213', 'LH213', 'Mất ngủ kéo dài', '117/75', 70, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ214', 'LH214', 'Thoái hóa khớp', '111/85', 62, 36.4, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ215', 'LH215', 'Dị ứng thời tiết', '114/74', 60, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ216', 'LH216', 'Loãng xương', '113/74', 86, 36.3, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ217', 'LH217', 'Mất ngủ kéo dài', '115/80', 83, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ218', 'LH218', 'Dị ứng thời tiết', '120/73', 61, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ219', 'LH219', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', '112/81', 78, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ220', 'LH220', 'Viêm gan C', '119/71', 68, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ221', 'LH221', 'Viêm phế quản mạn tính', '116/81', 80, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ222', 'LH222', 'Suy thận mạn', '132/82', 72, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ223', 'LH223', 'Loãng xương', '117/85', 69, 36.2, 'Chụp X-quang', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ224', 'LH224', 'Gout', '124/77', 86, 36.6, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ301', 'LH301', 'Test Procedure: Khớp cấu trúc bảng hóa đơn', '120/80', 85, 37.0, NULL, NULL, 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ225', 'LH225', 'Dị ứng thuốc', '123/80', 61, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ226', 'LH226', 'Suy tim', '145/90', 104, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ227', 'LH227', 'Suy tim', '147/95', 145, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ228', 'LH228', 'Dị ứng thực phẩm', '114/80', 72, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ229', 'LH229', 'Thoái hóa khớp', '111/85', 81, 36.5, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ230', 'LH230', 'Ung thư đại tràng', '116/83', 89, 36.8, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ231', 'LH231', 'Xơ gan', '117/78', 66, 36.7, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ232', 'LH232', 'Thiếu máu', '118/79', 80, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ233', 'LH233', 'sốt siêu vi', '114/73', 82, 37.2, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ234', 'LH234', 'Xơ gan', '113/79', 61, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ235', 'LH235', 'Viêm gan B', '112/85', 88, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ236', 'LH236', 'sốt siêu vi', '119/80', 81, 38.4, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ237', 'LH237', 'Viêm phế quản mạn tính', '113/76', 90, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ238', 'LH238', 'Trầm cảm', '112/78', 66, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ239', 'LH239', 'Tiểu đường tuýp 1', '136/87', 61, 36.8, 'Xét nghiệm đường huyết', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ240', 'LH240', 'Thiếu máu', '118/78', 63, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ241', 'LH241', 'Dị ứng thời tiết', '110/70', 64, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ242', 'LH242', 'Dị ứng thực phẩm', '114/74', 83, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ243', 'LH243', 'sốt siêu vi', '121/79', 72, 37.7, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ244', 'LH244', 'Suy tim', '154/97', 127, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ245', 'LH245', 'Tiểu đường tuýp 2', '136/89', 77, 36.7, 'Xét nghiệm đường huyết', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ246', 'LH246', 'Ung thư gan', '112/82', 80, 36.2, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ247', 'LH247', 'Ung thư đại tràng', '118/71', 80, 36.5, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ248', 'LH248', 'Ung thư phổi', '119/78', 74, 36.5, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ249', 'LH249', 'Bệnh tim mạch', '155/91', 107, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ250', 'LH250', 'Dị ứng thời tiết', '125/80', 78, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ251', 'LH251', 'sốt siêu vi', '118/74', 75, 37.1, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ252', 'LH252', 'Không có', '125/78', 65, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ253', 'LH253', 'Rối loạn lo âu', '113/71', 84, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ254', 'LH254', 'Dị ứng thực phẩm', '115/79', 63, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ255', 'LH255', 'Viêm phế quản mạn tính', '114/72', 64, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ256', 'LH256', 'Loãng xương', '111/76', 62, 36.1, 'Chụp X-quang', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ257', 'LH257', 'sốt xuất huyết', '124/81', 81, 39.4, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'CẢNH BÁO AI: Nguy cơ sốt co giật.', 0.85);
INSERT INTO public.ket_qua_kham VALUES ('KQ258', 'LH258', 'Dị ứng thời tiết', '117/71', 86, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ259', 'LH259', 'Tiểu đường tuýp 2', '130/80', 60, 36.4, 'Xét nghiệm đường huyết', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ260', 'LH260', 'Suy thận mạn', '134/82', 68, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ261', 'LH261', 'Ung thư vú', '125/80', 88, 36.2, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ262', 'LH262', 'Rối loạn mỡ máu', '118/83', 61, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ263', 'LH263', 'Viêm phế quản mạn tính', '112/84', 84, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ264', 'LH264', 'Xơ gan', '119/85', 78, 36.9, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ265', 'LH265', 'Không có', '113/72', 63, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ266', 'LH266', 'Viêm phế quản mạn tính', '125/74', 89, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ267', 'LH267', 'Viêm khớp dạng thấp', '110/80', 86, 36.1, 'Chụp X-quang', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ268', 'LH268', 'Ung thư gan', '116/82', 63, 36.6, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ269', 'LH269', 'Loãng xương', '125/73', 66, 36.5, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ270', 'LH270', 'Tăng huyết áp', '141/95', 73, 36.8, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ271', 'LH271', 'Tiểu đường tuýp 2', '137/86', 80, 36.9, 'Xét nghiệm đường huyết', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ273', 'LH273', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', '125/84', 72, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ274', 'LH274', 'Dị ứng thời tiết', '113/85', 65, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ275', 'LH275', 'Dị ứng thời tiết', '119/85', 61, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ276', 'LH276', 'Thoái hóa khớp', '120/80', 62, 36.8, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ277', 'LH277', 'Không có', '114/80', 87, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ278', 'LH278', 'Mất ngủ kéo dài', '116/81', 85, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ279', 'LH279', 'Sỏi thận', '121/85', 80, 36.3, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ280', 'LH280', 'Rối loạn lo âu', '111/72', 87, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ281', 'LH281', 'Trầm cảm', '112/71', 77, 36.2, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ282', 'LH282', 'Ung thư phổi', '110/78', 60, 36.7, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ283', 'LH283', 'Dị ứng thực phẩm', '120/85', 78, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ284', 'LH284', 'Tiểu đường tuýp 1', '130/87', 89, 36.1, 'Xét nghiệm đường huyết', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ285', 'LH285', 'Thoái hóa khớp', '120/73', 79, 36.6, 'Chụp X-quang', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ286', 'LH286', 'Ung thư đại tràng', '115/72', 60, 36.4, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ287', 'LH287', 'Suy thận mạn', '130/87', 70, 36.5, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ288', 'LH288', 'Rối loạn mỡ máu', '125/84', 83, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân có tiến triển', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ289', 'LH289', 'Thoái hóa khớp', '110/81', 63, 36.5, 'Chụp X-quang', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ290', 'LH290', 'Ung thư gan', '118/72', 78, 36.6, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ291', 'LH291', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', '118/85', 80, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ292', 'LH292', 'sốt xuất huyết', '122/84', 73, 37.3, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ293', 'LH293', 'sốt siêu vi', '125/79', 75, 37.4, 'Theo dõi định kỳ', 'Nghỉ ngơi. Uống nhiều nước', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ294', 'LH294', 'Ung thư đại tràng', '113/81', 90, 36.9, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ295', 'LH295', 'Bệnh phổi tắc nghẽn mạn tính (COPD)', '113/76', 82, 36.1, 'Theo dõi định kỳ', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ296', 'LH296', 'Bệnh tim mạch', '147/91', 125, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ297', 'LH297', 'Ung thư phổi', '110/75', 83, 36.8, 'Theo dõi định kỳ', 'Chuyển khoa chuyên môn', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ298', 'LH298', 'Sỏi thận', '112/81', 77, 36.4, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ299', 'LH299', 'Suy tim', '142/96', 110, 36.6, 'Theo dõi định kỳ', 'Bệnh nhân chưa ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);
INSERT INTO public.ket_qua_kham VALUES ('KQ300', 'LH300', 'Tiểu đường tuýp 2', '135/85', 85, 36.4, 'Xét nghiệm đường huyết', 'Bệnh nhân ổn định', 'AI: Chỉ số trong ngưỡng an toàn.', 0.95);


--
-- TOC entry 5072 (class 0 OID 17056)
-- Dependencies: 217
-- Data for Name: khach_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.khach_hang VALUES ('KH001', 'Đặng Thanh Quân', '0747202721', 'khachhang575_kh001@gmail.com', 'Cho999!');
INSERT INTO public.khach_hang VALUES ('KH002', 'Hoàng Hoàng Linh', '0333322770', 'khachhang455_kh002@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH003', 'Vũ Khánh Bình', '0701416940', 'khachhang555_kh003@gmail.com', 'Yeu999!');
INSERT INTO public.khach_hang VALUES ('KH004', 'Bùi Khánh An', '0957760683', 'khachhang438_kh004@gmail.com', 'Yeu888@');
INSERT INTO public.khach_hang VALUES ('KH005', 'Phan Thị Thảo', '0555388213', 'khachhang838_kh005@gmail.com', 'Yeu2026!');
INSERT INTO public.khach_hang VALUES ('KH006', 'Phan Văn An', '0730588564', 'khachhang543_kh006@gmail.com', 'An2026!');
INSERT INTO public.khach_hang VALUES ('KH007', 'Nguyễn Khánh Nam', '0977043963', 'khachhang477_kh007@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH008', 'Phan Anh Bình', '0338935931', 'khachhang705_kh008@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH009', 'Bùi Văn Thảo', '0873634629', 'khachhang361_kh009@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH010', 'Phan Minh Dũng', '0502146835', 'khachhang526_kh010@gmail.com', 'Cho123!');
INSERT INTO public.khach_hang VALUES ('KH011', 'Phạm Thị Tuấn', '0572028046', 'khachhang564_kh011@gmail.com', 'An888!');
INSERT INTO public.khach_hang VALUES ('KH012', 'Phạm Hoàng Linh', '0764053890', 'khachhang164_kh012@gmail.com', 'Pass123#');
INSERT INTO public.khach_hang VALUES ('KH013', 'Bùi Hoàng An', '0826171609', 'khachhang878_kh013@gmail.com', 'Yeu2026@');
INSERT INTO public.khach_hang VALUES ('KH014', 'Phạm Gia Linh', '0903643947', 'khachhang127_kh014@gmail.com', 'Yeu999#');
INSERT INTO public.khach_hang VALUES ('KH015', 'Hoàng Anh Quân', '0947076505', 'khachhang347_kh015@gmail.com', 'An888!');
INSERT INTO public.khach_hang VALUES ('KH016', 'Nguyễn Anh Em', '0389613363', 'khachhang522_kh016@gmail.com', 'Yeu999@');
INSERT INTO public.khach_hang VALUES ('KH017', 'Đỗ Khánh Khôi', '0317315430', 'khachhang586_kh017@gmail.com', 'Pass2026#');
INSERT INTO public.khach_hang VALUES ('KH018', 'Nguyễn Khánh Thảo', '0708945677', 'khachhang437_kh018@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH019', 'Đặng Thanh Dũng', '0348475631', 'khachhang848_kh019@gmail.com', 'Pass2026@');
INSERT INTO public.khach_hang VALUES ('KH020', 'Trần Ngọc Nam', '0878129897', 'khachhang592_kh020@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH021', 'Đỗ Gia Quân', '0851642889', 'khachhang596_kh021@gmail.com', 'An2026!');
INSERT INTO public.khach_hang VALUES ('KH022', 'Phạm Thị Tuấn', '0559687910', 'khachhang754_kh022@gmail.com', 'Pass123!');
INSERT INTO public.khach_hang VALUES ('KH023', 'Vũ Thị Em', '0722598478', 'khachhang491_kh023@gmail.com', 'An123#');
INSERT INTO public.khach_hang VALUES ('KH024', 'Trần Ngọc Quân', '0801175271', 'khachhang839_kh024@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH025', 'Bùi Khánh Hương', '0569082727', 'khachhang220_kh025@gmail.com', 'An2026@');
INSERT INTO public.khach_hang VALUES ('KH026', 'Đỗ Minh Nam', '0743172710', 'khachhang668_kh026@gmail.com', 'Pass123!');
INSERT INTO public.khach_hang VALUES ('KH027', 'Phan Văn Em', '0971848753', 'khachhang604_kh027@gmail.com', 'Yeu999#');
INSERT INTO public.khach_hang VALUES ('KH028', 'Nguyễn Khánh Tuấn', '0566334454', 'khachhang818_kh028@gmail.com', 'An2026#');
INSERT INTO public.khach_hang VALUES ('KH029', 'Đặng Ngọc Hương', '0361495481', 'khachhang227_kh029@gmail.com', 'Pass123#');
INSERT INTO public.khach_hang VALUES ('KH030', 'Lê Thị Chi', '0592339471', 'khachhang500_kh030@gmail.com', 'Cho999!');
INSERT INTO public.khach_hang VALUES ('KH031', 'Đặng Anh Khôi', '0819898950', 'khachhang711_kh031@gmail.com', 'Cho888!');
INSERT INTO public.khach_hang VALUES ('KH032', 'Phan Hoàng Nam', '0541467666', 'khachhang115_kh032@gmail.com', 'Pass2026!');
INSERT INTO public.khach_hang VALUES ('KH033', 'Phan Hoàng Bình', '0952169904', 'khachhang198_kh033@gmail.com', 'Yeu888#');
INSERT INTO public.khach_hang VALUES ('KH034', 'Hoàng Hoàng Hương', '0829487781', 'khachhang651_kh034@gmail.com', 'Yeu123@');
INSERT INTO public.khach_hang VALUES ('KH035', 'Đặng Khánh An', '0989389721', 'khachhang203_kh035@gmail.com', 'Yeu2026#');
INSERT INTO public.khach_hang VALUES ('KH036', 'Vũ Hoàng Bình', '0374554233', 'khachhang643_kh036@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH037', 'Phan Hoàng Dũng', '0786059312', 'khachhang484_kh037@gmail.com', 'Yeu123@');
INSERT INTO public.khach_hang VALUES ('KH038', 'Trần Gia Khôi', '0845734542', 'khachhang148_kh038@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH039', 'Phan Thanh Em', '0884876291', 'khachhang292_kh039@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH040', 'Phan Khánh Tuấn', '0888626908', 'khachhang136_kh040@gmail.com', 'Yeu888!');
INSERT INTO public.khach_hang VALUES ('KH041', 'Bùi Minh Em', '0766118817', 'khachhang411_kh041@gmail.com', 'Cho888@');
INSERT INTO public.khach_hang VALUES ('KH042', 'Phan Khánh Khôi', '0764017701', 'khachhang464_kh042@gmail.com', 'Pass999@');
INSERT INTO public.khach_hang VALUES ('KH043', 'Lê Thanh Tuấn', '0768181826', 'khachhang355_kh043@gmail.com', 'Pass123!');
INSERT INTO public.khach_hang VALUES ('KH044', 'Phan Hoàng Em', '0826611580', 'khachhang244_kh044@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH045', 'Phạm Hoàng Khôi', '0558734017', 'khachhang244_kh045@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH046', 'Đặng Thanh Hương', '0957001963', 'khachhang747_kh046@gmail.com', 'An888!');
INSERT INTO public.khach_hang VALUES ('KH047', 'Trần Hoàng Tuấn', '0883632746', 'khachhang239_kh047@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH048', 'Đặng Hoàng Khôi', '0823570994', 'khachhang761_kh048@gmail.com', 'Pass999@');
INSERT INTO public.khach_hang VALUES ('KH049', 'Hoàng Thị Linh', '0840802463', 'khachhang607_kh049@gmail.com', 'Pass999!');
INSERT INTO public.khach_hang VALUES ('KH050', 'Nguyễn Khánh Hương', '0882773842', 'khachhang430_kh050@gmail.com', 'Pass999!');
INSERT INTO public.khach_hang VALUES ('KH051', 'Phan Thị Bình', '0987363603', 'khachhang231_kh051@gmail.com', 'An888@');
INSERT INTO public.khach_hang VALUES ('KH052', 'Phạm Anh Thảo', '0399053600', 'khachhang132_kh052@gmail.com', 'An888!');
INSERT INTO public.khach_hang VALUES ('KH053', 'Trần Khánh Bình', '0918262901', 'khachhang782_kh053@gmail.com', 'An888!');
INSERT INTO public.khach_hang VALUES ('KH054', 'Nguyễn Anh Hương', '0783161068', 'khachhang676_kh054@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH055', 'Đỗ Ngọc Em', '0340791973', 'khachhang355_kh055@gmail.com', 'Cho123#');
INSERT INTO public.khach_hang VALUES ('KH056', 'Trần Thị Quân', '0712438001', 'khachhang987_kh056@gmail.com', 'An2026!');
INSERT INTO public.khach_hang VALUES ('KH057', 'Đỗ Minh Nam', '0858367277', 'khachhang304_kh057@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH058', 'Phạm Ngọc Nam', '0315416409', 'khachhang237_kh058@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH059', 'Nguyễn Văn Bình', '0337624948', 'khachhang648_kh059@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH060', 'Lê Gia Em', '0794881638', 'khachhang630_kh060@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH061', 'Phạm Khánh Em', '0913512384', 'khachhang712_kh061@gmail.com', 'An123@');
INSERT INTO public.khach_hang VALUES ('KH062', 'Phan Khánh Em', '0970470862', 'khachhang962_kh062@gmail.com', 'An2026@');
INSERT INTO public.khach_hang VALUES ('KH063', 'Trần Hoàng An', '0830925298', 'khachhang561_kh063@gmail.com', 'Cho888@');
INSERT INTO public.khach_hang VALUES ('KH064', 'Đặng Thanh Thảo', '0825708788', 'khachhang390_kh064@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH065', 'Lê Minh Bình', '0598471600', 'khachhang957_kh065@gmail.com', 'Pass2026#');
INSERT INTO public.khach_hang VALUES ('KH066', 'Phan Thanh Thảo', '0583391815', 'khachhang163_kh066@gmail.com', 'An123#');
INSERT INTO public.khach_hang VALUES ('KH067', 'Lê Thanh Bình', '0947805486', 'khachhang980_kh067@gmail.com', 'Pass999!');
INSERT INTO public.khach_hang VALUES ('KH068', 'Lê Anh Khôi', '0713215155', 'khachhang237_kh068@gmail.com', 'An888@');
INSERT INTO public.khach_hang VALUES ('KH069', 'Đỗ Minh Chi', '0340163497', 'khachhang744_kh069@gmail.com', 'Cho999!');
INSERT INTO public.khach_hang VALUES ('KH070', 'Đỗ Thị Bình', '0829540341', 'khachhang164_kh070@gmail.com', 'Pass999#');
INSERT INTO public.khach_hang VALUES ('KH071', 'Phạm Hoàng Hương', '0912364856', 'khachhang499_kh071@gmail.com', 'An2026@');
INSERT INTO public.khach_hang VALUES ('KH072', 'Đỗ Gia An', '0828861305', 'khachhang362_kh072@gmail.com', 'Yeu999!');
INSERT INTO public.khach_hang VALUES ('KH073', 'Nguyễn Thị Khôi', '0960742064', 'khachhang384_kh073@gmail.com', 'Yeu999@');
INSERT INTO public.khach_hang VALUES ('KH074', 'Nguyễn Thanh Em', '0730291441', 'khachhang279_kh074@gmail.com', 'Cho2026!');
INSERT INTO public.khach_hang VALUES ('KH075', 'Nguyễn Hoàng Dũng', '0722861150', 'khachhang233_kh075@gmail.com', 'Yeu123@');
INSERT INTO public.khach_hang VALUES ('KH076', 'Nguyễn Văn Nam', '0348260372', 'khachhang234_kh076@gmail.com', 'Yeu999#');
INSERT INTO public.khach_hang VALUES ('KH077', 'Hoàng Hoàng Dũng', '0937088664', 'khachhang979_kh077@gmail.com', 'An999#');
INSERT INTO public.khach_hang VALUES ('KH078', 'Phạm Thị Em', '0990811931', 'khachhang827_kh078@gmail.com', 'Cho123@');
INSERT INTO public.khach_hang VALUES ('KH079', 'Nguyễn Ngọc Linh', '0959264792', 'khachhang952_kh079@gmail.com', 'Pass2026@');
INSERT INTO public.khach_hang VALUES ('KH080', 'Trần Thị Chi', '0830896594', 'khachhang978_kh080@gmail.com', 'An2026#');
INSERT INTO public.khach_hang VALUES ('KH081', 'Hoàng Gia Tuấn', '0815362985', 'khachhang965_kh081@gmail.com', 'Yeu888#');
INSERT INTO public.khach_hang VALUES ('KH082', 'Vũ Văn Khôi', '0760550476', 'khachhang151_kh082@gmail.com', 'Cho2026@');
INSERT INTO public.khach_hang VALUES ('KH083', 'Lê Thanh Nam', '0769911750', 'khachhang241_kh083@gmail.com', 'Pass2026!');
INSERT INTO public.khach_hang VALUES ('KH084', 'Vũ Anh An', '0511681815', 'khachhang945_kh084@gmail.com', 'Yeu888#');
INSERT INTO public.khach_hang VALUES ('KH085', 'Bùi Thanh Quân', '0732545661', 'khachhang283_kh085@gmail.com', 'Cho2026#');
INSERT INTO public.khach_hang VALUES ('KH086', 'Nguyễn Thanh An', '0866805767', 'khachhang572_kh086@gmail.com', 'Cho2026#');
INSERT INTO public.khach_hang VALUES ('KH087', 'Bùi Thanh Nam', '0590359861', 'khachhang258_kh087@gmail.com', 'Cho2026#');
INSERT INTO public.khach_hang VALUES ('KH088', 'Hoàng Văn Bình', '0304765184', 'khachhang891_kh088@gmail.com', 'Cho123#');
INSERT INTO public.khach_hang VALUES ('KH089', 'Nguyễn Gia Bình', '0903121435', 'khachhang230_kh089@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH090', 'Lê Anh Quân', '0984124137', 'khachhang592_kh090@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH091', 'Đặng Thanh An', '0936502859', 'khachhang694_kh091@gmail.com', 'An2026!');
INSERT INTO public.khach_hang VALUES ('KH092', 'Bùi Thanh Nam', '0973074833', 'khachhang157_kh092@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH093', 'Vũ Minh Thảo', '0842794401', 'khachhang781_kh093@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH094', 'Phan Hoàng An', '0725396282', 'khachhang467_kh094@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH095', 'Phan Anh Dũng', '0570164248', 'khachhang998_kh095@gmail.com', 'Cho123#');
INSERT INTO public.khach_hang VALUES ('KH096', 'Vũ Hoàng Tuấn', '0578058923', 'khachhang598_kh096@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH097', 'Bùi Thị Em', '0947754188', 'khachhang867_kh097@gmail.com', 'An999#');
INSERT INTO public.khach_hang VALUES ('KH098', 'Phan Thanh Em', '0991166313', 'khachhang871_kh098@gmail.com', 'An2026@');
INSERT INTO public.khach_hang VALUES ('KH099', 'Phạm Ngọc Thảo', '0574294314', 'khachhang924_kh099@gmail.com', 'Cho999!');
INSERT INTO public.khach_hang VALUES ('KH100', 'Phạm Gia Dũng', '0965241319', 'khachhang239_kh100@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH101', 'Bùi Anh Hương', '0847872582', 'khachhang101_kh101@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH102', 'Trần Khánh An', '0864466225', 'khachhang920_kh102@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH103', 'Hoàng Minh Nam', '0955837624', 'khachhang648_kh103@gmail.com', 'Yeu2026!');
INSERT INTO public.khach_hang VALUES ('KH104', 'Nguyễn Thị Nam', '0842481900', 'khachhang338_kh104@gmail.com', 'Cho123#');
INSERT INTO public.khach_hang VALUES ('KH105', 'Lê Thanh Bình', '0871326345', 'khachhang599_kh105@gmail.com', 'Pass999@');
INSERT INTO public.khach_hang VALUES ('KH106', 'Bùi Văn Em', '0335756198', 'khachhang125_kh106@gmail.com', 'Yeu999!');
INSERT INTO public.khach_hang VALUES ('KH107', 'Nguyễn Ngọc An', '0524647316', 'khachhang670_kh107@gmail.com', 'An999#');
INSERT INTO public.khach_hang VALUES ('KH108', 'Trần Khánh Nam', '0542585441', 'khachhang654_kh108@gmail.com', 'Cho999!');
INSERT INTO public.khach_hang VALUES ('KH109', 'Hoàng Khánh Hương', '0814248480', 'khachhang536_kh109@gmail.com', 'Yeu999!');
INSERT INTO public.khach_hang VALUES ('KH110', 'Trần Văn Khôi', '0565047327', 'khachhang656_kh110@gmail.com', 'Yeu2026#');
INSERT INTO public.khach_hang VALUES ('KH111', 'Trần Khánh Hương', '0512134622', 'khachhang151_kh111@gmail.com', 'Cho888#');
INSERT INTO public.khach_hang VALUES ('KH112', 'Bùi Hoàng Nam', '0734952873', 'khachhang414_kh112@gmail.com', 'An2026!');
INSERT INTO public.khach_hang VALUES ('KH113', 'Bùi Ngọc Em', '0597621198', 'khachhang719_kh113@gmail.com', 'Pass888@');
INSERT INTO public.khach_hang VALUES ('KH114', 'Lê Thị Thảo', '0364500226', 'khachhang378_kh114@gmail.com', 'Pass2026@');
INSERT INTO public.khach_hang VALUES ('KH115', 'Hoàng Thanh Linh', '0753440111', 'khachhang508_kh115@gmail.com', 'Cho123#');
INSERT INTO public.khach_hang VALUES ('KH116', 'Đặng Minh Linh', '0823804561', 'khachhang348_kh116@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH117', 'Đỗ Khánh Em', '0503193640', 'khachhang163_kh117@gmail.com', 'Yeu123@');
INSERT INTO public.khach_hang VALUES ('KH118', 'Phan Văn Thảo', '0570581201', 'khachhang806_kh118@gmail.com', 'Yeu888!');
INSERT INTO public.khach_hang VALUES ('KH119', 'Lê Khánh Linh', '0783202986', 'khachhang747_kh119@gmail.com', 'Pass888!');
INSERT INTO public.khach_hang VALUES ('KH120', 'Vũ Gia Khôi', '0818556929', 'khachhang549_kh120@gmail.com', 'Pass123#');
INSERT INTO public.khach_hang VALUES ('KH121', 'Lê Hoàng Dũng', '0832933442', 'khachhang838_kh121@gmail.com', 'Pass123!');
INSERT INTO public.khach_hang VALUES ('KH122', 'Hoàng Thanh Linh', '0579007306', 'khachhang479_kh122@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH123', 'Lê Khánh Chi', '0574764688', 'khachhang819_kh123@gmail.com', 'An999#');
INSERT INTO public.khach_hang VALUES ('KH124', 'Đặng Khánh Hương', '0584199825', 'khachhang456_kh124@gmail.com', 'An123@');
INSERT INTO public.khach_hang VALUES ('KH125', 'Hoàng Ngọc Khôi', '0374042604', 'khachhang743_kh125@gmail.com', 'Yeu888#');
INSERT INTO public.khach_hang VALUES ('KH126', 'Phạm Ngọc Em', '0753553125', 'khachhang759_kh126@gmail.com', 'Pass2026#');
INSERT INTO public.khach_hang VALUES ('KH127', 'Hoàng Khánh Em', '0583695687', 'khachhang977_kh127@gmail.com', 'Yeu2026!');
INSERT INTO public.khach_hang VALUES ('KH128', 'Phan Thị Thảo', '0972237286', 'khachhang719_kh128@gmail.com', 'Pass2026#');
INSERT INTO public.khach_hang VALUES ('KH129', 'Vũ Minh Em', '0726506951', 'khachhang788_kh129@gmail.com', 'Yeu123!');
INSERT INTO public.khach_hang VALUES ('KH130', 'Bùi Anh Bình', '0788311886', 'khachhang296_kh130@gmail.com', 'Cho123@');
INSERT INTO public.khach_hang VALUES ('KH131', 'Bùi Hoàng Chi', '0821077403', 'khachhang935_kh131@gmail.com', 'Pass999#');
INSERT INTO public.khach_hang VALUES ('KH132', 'Lê Gia Dũng', '0395774305', 'khachhang504_kh132@gmail.com', 'Cho999!');
INSERT INTO public.khach_hang VALUES ('KH133', 'Phạm Hoàng Linh', '0955448232', 'khachhang786_kh133@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH134', 'Bùi Minh Quân', '0771451031', 'khachhang327_kh134@gmail.com', 'An888#');
INSERT INTO public.khach_hang VALUES ('KH135', 'Đỗ Thị Hương', '0785851544', 'khachhang559_kh135@gmail.com', 'Pass123#');
INSERT INTO public.khach_hang VALUES ('KH136', 'Phạm Khánh Tuấn', '0302816476', 'khachhang878_kh136@gmail.com', 'Yeu888@');
INSERT INTO public.khach_hang VALUES ('KH137', 'Nguyễn Thị Em', '0870466778', 'khachhang810_kh137@gmail.com', 'Pass999#');
INSERT INTO public.khach_hang VALUES ('KH138', 'Trần Khánh Bình', '0387216979', 'khachhang149_kh138@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH139', 'Đỗ Khánh Nam', '0383897887', 'khachhang182_kh139@gmail.com', 'Yeu2026@');
INSERT INTO public.khach_hang VALUES ('KH140', 'Đỗ Hoàng Quân', '0998255195', 'khachhang427_kh140@gmail.com', 'Cho123@');
INSERT INTO public.khach_hang VALUES ('KH141', 'Hoàng Ngọc Hương', '0347585252', 'khachhang646_kh141@gmail.com', 'Pass999@');
INSERT INTO public.khach_hang VALUES ('KH142', 'Trần Khánh Khôi', '0862496749', 'khachhang581_kh142@gmail.com', 'Pass999@');
INSERT INTO public.khach_hang VALUES ('KH143', 'Nguyễn Ngọc Bình', '0798977035', 'khachhang777_kh143@gmail.com', 'An123@');
INSERT INTO public.khach_hang VALUES ('KH144', 'Phạm Thị Thảo', '0905609297', 'khachhang590_kh144@gmail.com', 'Yeu2026#');
INSERT INTO public.khach_hang VALUES ('KH145', 'Phạm Hoàng Khôi', '0757201680', 'khachhang821_kh145@gmail.com', 'An2026#');
INSERT INTO public.khach_hang VALUES ('KH146', 'Đỗ Gia Khôi', '0567481824', 'khachhang663_kh146@gmail.com', 'An2026#');
INSERT INTO public.khach_hang VALUES ('KH147', 'Hoàng Gia Thảo', '0973180767', 'khachhang216_kh147@gmail.com', 'An999#');
INSERT INTO public.khach_hang VALUES ('KH148', 'Trần Khánh Thảo', '0772307542', 'khachhang330_kh148@gmail.com', 'An888@');
INSERT INTO public.khach_hang VALUES ('KH149', 'Bùi Văn Thảo', '0398031563', 'khachhang231_kh149@gmail.com', 'An888!');
INSERT INTO public.khach_hang VALUES ('KH150', 'Lê Gia Hương', '0836612567', 'khachhang664_kh150@gmail.com', 'Yeu2026!');
INSERT INTO public.khach_hang VALUES ('KH151', 'Đỗ Hoàng Nam', '0933882484', 'khachhang622_kh151@gmail.com', 'An888@');
INSERT INTO public.khach_hang VALUES ('KH152', 'Bùi Thị Tuấn', '0804982297', 'khachhang313_kh152@gmail.com', 'Pass999!');
INSERT INTO public.khach_hang VALUES ('KH153', 'Lê Minh An', '0840173769', 'khachhang757_kh153@gmail.com', 'Pass888!');
INSERT INTO public.khach_hang VALUES ('KH154', 'Đặng Minh Linh', '0347104690', 'khachhang276_kh154@gmail.com', 'Yeu888!');
INSERT INTO public.khach_hang VALUES ('KH155', 'Hoàng Gia An', '0945029664', 'khachhang400_kh155@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH156', 'Lê Minh Dũng', '0939988256', 'khachhang503_kh156@gmail.com', 'Pass2026#');
INSERT INTO public.khach_hang VALUES ('KH157', 'Lê Gia Chi', '0700703276', 'khachhang945_kh157@gmail.com', 'Pass888#');
INSERT INTO public.khach_hang VALUES ('KH158', 'Đỗ Hoàng Em', '0830088468', 'khachhang800_kh158@gmail.com', 'Cho2026#');
INSERT INTO public.khach_hang VALUES ('KH159', 'Vũ Thị Tuấn', '0363219738', 'khachhang467_kh159@gmail.com', 'Cho999!');
INSERT INTO public.khach_hang VALUES ('KH160', 'Đỗ Thị Khôi', '0501628927', 'khachhang310_kh160@gmail.com', 'Pass888#');
INSERT INTO public.khach_hang VALUES ('KH161', 'Phan Anh Linh', '0754188352', 'khachhang778_kh161@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH162', 'Đặng Thị Nam', '0948812121', 'khachhang344_kh162@gmail.com', 'Pass999@');
INSERT INTO public.khach_hang VALUES ('KH163', 'Hoàng Khánh Thảo', '0361779541', 'khachhang115_kh163@gmail.com', 'Cho2026#');
INSERT INTO public.khach_hang VALUES ('KH164', 'Phạm Anh Hương', '0820386225', 'khachhang751_kh164@gmail.com', 'Cho888#');
INSERT INTO public.khach_hang VALUES ('KH165', 'Vũ Gia Dũng', '0506549337', 'khachhang623_kh165@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH166', 'Vũ Văn An', '0935414109', 'khachhang940_kh166@gmail.com', 'An2026#');
INSERT INTO public.khach_hang VALUES ('KH167', 'Phạm Thanh Chi', '0527386141', 'khachhang143_kh167@gmail.com', 'Pass123!');
INSERT INTO public.khach_hang VALUES ('KH168', 'Phạm Hoàng Tuấn', '0983397874', 'khachhang102_kh168@gmail.com', 'Yeu2026!');
INSERT INTO public.khach_hang VALUES ('KH169', 'Bùi Minh Chi', '0729121991', 'khachhang425_kh169@gmail.com', 'An123#');
INSERT INTO public.khach_hang VALUES ('KH170', 'Đỗ Thị Em', '0946180337', 'khachhang218_kh170@gmail.com', 'Yeu999#');
INSERT INTO public.khach_hang VALUES ('KH171', 'Phan Anh Dũng', '0306136239', 'khachhang182_kh171@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH172', 'Đỗ Ngọc Em', '0975688298', 'khachhang753_kh172@gmail.com', 'Yeu123@');
INSERT INTO public.khach_hang VALUES ('KH173', 'Trần Gia Hương', '0710425962', 'khachhang867_kh173@gmail.com', 'Yeu123!');
INSERT INTO public.khach_hang VALUES ('KH174', 'Bùi Anh Chi', '0735555410', 'khachhang561_kh174@gmail.com', 'Cho888@');
INSERT INTO public.khach_hang VALUES ('KH175', 'Hoàng Minh Nam', '0748036665', 'khachhang712_kh175@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH176', 'Bùi Thị Dũng', '0575424204', 'khachhang259_kh176@gmail.com', 'Pass2026!');
INSERT INTO public.khach_hang VALUES ('KH177', 'Đỗ Thị Em', '0709797427', 'khachhang795_kh177@gmail.com', 'An999#');
INSERT INTO public.khach_hang VALUES ('KH178', 'Trần Ngọc Chi', '0372414674', 'khachhang577_kh178@gmail.com', 'An2026#');
INSERT INTO public.khach_hang VALUES ('KH179', 'Vũ Anh Hương', '0743156117', 'khachhang718_kh179@gmail.com', 'Yeu2026!');
INSERT INTO public.khach_hang VALUES ('KH180', 'Hoàng Văn Dũng', '0556066818', 'khachhang575_kh180@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH181', 'Đỗ Gia Dũng', '0805605244', 'khachhang354_kh181@gmail.com', 'Pass999#');
INSERT INTO public.khach_hang VALUES ('KH182', 'Phạm Thanh Bình', '0588690855', 'khachhang449_kh182@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH183', 'Vũ Thị Chi', '0314228986', 'khachhang432_kh183@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH184', 'Lê Minh Linh', '0365530442', 'khachhang901_kh184@gmail.com', 'Pass888@');
INSERT INTO public.khach_hang VALUES ('KH185', 'Phan Gia Bình', '0865384391', 'khachhang973_kh185@gmail.com', 'Pass2026!');
INSERT INTO public.khach_hang VALUES ('KH186', 'Nguyễn Văn Thảo', '0829881986', 'khachhang354_kh186@gmail.com', 'Cho888!');
INSERT INTO public.khach_hang VALUES ('KH187', 'Phan Thanh Tuấn', '0390480564', 'khachhang750_kh187@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH188', 'Phạm Gia Nam', '0779654694', 'khachhang924_kh188@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH189', 'Hoàng Thanh Khôi', '0763502388', 'khachhang686_kh189@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH190', 'Phan Minh Tuấn', '0352720216', 'khachhang215_kh190@gmail.com', 'Pass2026!');
INSERT INTO public.khach_hang VALUES ('KH191', 'Trần Hoàng Khôi', '0837389955', 'khachhang711_kh191@gmail.com', 'Pass888@');
INSERT INTO public.khach_hang VALUES ('KH192', 'Trần Hoàng Linh', '0512854219', 'khachhang151_kh192@gmail.com', 'An123#');
INSERT INTO public.khach_hang VALUES ('KH193', 'Lê Minh Nam', '0584208808', 'khachhang218_kh193@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH194', 'Vũ Hoàng Khôi', '0509775054', 'khachhang187_kh194@gmail.com', 'Yeu2026!');
INSERT INTO public.khach_hang VALUES ('KH195', 'Nguyễn Gia Thảo', '0925720080', 'khachhang730_kh195@gmail.com', 'Yeu123@');
INSERT INTO public.khach_hang VALUES ('KH196', 'Đặng Thị An', '0525247367', 'khachhang119_kh196@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH197', 'Đỗ Minh Linh', '0797861195', 'khachhang975_kh197@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH198', 'Phan Văn An', '0574401559', 'khachhang143_kh198@gmail.com', 'An888!');
INSERT INTO public.khach_hang VALUES ('KH199', 'Đặng Minh Dũng', '0502304153', 'khachhang827_kh199@gmail.com', 'Pass2026!');
INSERT INTO public.khach_hang VALUES ('KH200', 'Bùi Ngọc Quân', '0724975223', 'khachhang658_kh200@gmail.com', 'Pass123!');
INSERT INTO public.khach_hang VALUES ('KH201', 'Trần Anh Linh', '0903445393', 'khachhang175_kh201@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH202', 'Phạm Thị Hương', '0563242982', 'khachhang752_kh202@gmail.com', 'An123@');
INSERT INTO public.khach_hang VALUES ('KH203', 'Trần Gia Nam', '0944860576', 'khachhang141_kh203@gmail.com', 'Yeu2026@');
INSERT INTO public.khach_hang VALUES ('KH204', 'Trần Khánh Chi', '0905490267', 'khachhang221_kh204@gmail.com', 'Pass888#');
INSERT INTO public.khach_hang VALUES ('KH205', 'Bùi Hoàng Khôi', '0318575417', 'khachhang229_kh205@gmail.com', 'An888!');
INSERT INTO public.khach_hang VALUES ('KH206', 'Phan Khánh Nam', '0766396071', 'khachhang861_kh206@gmail.com', 'Cho888@');
INSERT INTO public.khach_hang VALUES ('KH207', 'Phan Khánh Quân', '0309754892', 'khachhang301_kh207@gmail.com', 'Yeu888@');
INSERT INTO public.khach_hang VALUES ('KH208', 'Vũ Hoàng Chi', '0575551320', 'khachhang540_kh208@gmail.com', 'Pass123#');
INSERT INTO public.khach_hang VALUES ('KH209', 'Trần Ngọc Thảo', '0527143629', 'khachhang338_kh209@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH210', 'Bùi Khánh Hương', '0354884499', 'khachhang909_kh210@gmail.com', 'Pass888#');
INSERT INTO public.khach_hang VALUES ('KH211', 'Phạm Hoàng Em', '0579593574', 'khachhang334_kh211@gmail.com', 'Pass888#');
INSERT INTO public.khach_hang VALUES ('KH212', 'Trần Minh Quân', '0568645746', 'khachhang861_kh212@gmail.com', 'Pass999!');
INSERT INTO public.khach_hang VALUES ('KH213', 'Đỗ Khánh Quân', '0584060872', 'khachhang398_kh213@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH214', 'Đặng Khánh Bình', '0382139263', 'khachhang542_kh214@gmail.com', 'Pass123#');
INSERT INTO public.khach_hang VALUES ('KH215', 'Đỗ Văn Khôi', '0724137090', 'khachhang244_kh215@gmail.com', 'Cho888#');
INSERT INTO public.khach_hang VALUES ('KH216', 'Đỗ Khánh Dũng', '0908619040', 'khachhang535_kh216@gmail.com', 'An2026#');
INSERT INTO public.khach_hang VALUES ('KH217', 'Vũ Anh An', '0783072429', 'khachhang424_kh217@gmail.com', 'Pass2026#');
INSERT INTO public.khach_hang VALUES ('KH218', 'Lê Gia Quân', '0314658066', 'khachhang686_kh218@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH219', 'Phạm Thanh Hương', '0819770600', 'khachhang644_kh219@gmail.com', 'Pass888#');
INSERT INTO public.khach_hang VALUES ('KH220', 'Phạm Ngọc Tuấn', '0973411411', 'khachhang237_kh220@gmail.com', 'Yeu2026@');
INSERT INTO public.khach_hang VALUES ('KH221', 'Nguyễn Minh Dũng', '0715154392', 'khachhang774_kh221@gmail.com', 'Pass2026@');
INSERT INTO public.khach_hang VALUES ('KH222', 'Đỗ Khánh Em', '0948819007', 'khachhang664_kh222@gmail.com', 'Yeu123@');
INSERT INTO public.khach_hang VALUES ('KH223', 'Phan Văn Nam', '0916995344', 'khachhang247_kh223@gmail.com', 'Cho888@');
INSERT INTO public.khach_hang VALUES ('KH224', 'Phan Văn An', '0575660522', 'khachhang508_kh224@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH225', 'Phạm Hoàng Linh', '0305085924', 'khachhang447_kh225@gmail.com', 'An999!');
INSERT INTO public.khach_hang VALUES ('KH226', 'Bùi Anh Em', '0830529444', 'khachhang327_kh226@gmail.com', 'Pass2026@');
INSERT INTO public.khach_hang VALUES ('KH227', 'Vũ Anh Chi', '0883947942', 'khachhang346_kh227@gmail.com', 'An999!');
INSERT INTO public.khach_hang VALUES ('KH228', 'Phạm Văn Nam', '0532992241', 'khachhang903_kh228@gmail.com', 'Cho2026!');
INSERT INTO public.khach_hang VALUES ('KH229', 'Đặng Thị Em', '0875344682', 'khachhang342_kh229@gmail.com', 'Yeu2026#');
INSERT INTO public.khach_hang VALUES ('KH230', 'Lê Anh Em', '0799959646', 'khachhang917_kh230@gmail.com', 'Cho2026@');
INSERT INTO public.khach_hang VALUES ('KH231', 'Nguyễn Hoàng An', '0794471918', 'khachhang239_kh231@gmail.com', 'Yeu999@');
INSERT INTO public.khach_hang VALUES ('KH232', 'Đỗ Văn Dũng', '0850252963', 'khachhang933_kh232@gmail.com', 'An2026@');
INSERT INTO public.khach_hang VALUES ('KH233', 'Phan Ngọc Chi', '0538795799', 'khachhang697_kh233@gmail.com', 'Pass999@');
INSERT INTO public.khach_hang VALUES ('KH234', 'Đặng Ngọc An', '0335632009', 'khachhang268_kh234@gmail.com', 'Pass888@');
INSERT INTO public.khach_hang VALUES ('KH235', 'Phan Khánh Tuấn', '0304725756', 'khachhang997_kh235@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH236', 'Đỗ Khánh Tuấn', '0532409453', 'khachhang846_kh236@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH237', 'Trần Minh Linh', '0315581283', 'khachhang421_kh237@gmail.com', 'Pass888@');
INSERT INTO public.khach_hang VALUES ('KH238', 'Lê Khánh Bình', '0791224774', 'khachhang160_kh238@gmail.com', 'Yeu123@');
INSERT INTO public.khach_hang VALUES ('KH239', 'Phan Anh Em', '0948033578', 'khachhang597_kh239@gmail.com', 'Pass999@');
INSERT INTO public.khach_hang VALUES ('KH240', 'Phạm Minh Linh', '0336625742', 'khachhang179_kh240@gmail.com', 'Yeu999#');
INSERT INTO public.khach_hang VALUES ('KH241', 'Bùi Hoàng An', '0985626336', 'khachhang521_kh241@gmail.com', 'Cho999!');
INSERT INTO public.khach_hang VALUES ('KH242', 'Phạm Anh Linh', '0790096888', 'khachhang808_kh242@gmail.com', 'Cho2026#');
INSERT INTO public.khach_hang VALUES ('KH243', 'Trần Gia Thảo', '0570945145', 'khachhang201_kh243@gmail.com', 'Cho888@');
INSERT INTO public.khach_hang VALUES ('KH244', 'Đỗ Minh Nam', '0767677042', 'khachhang260_kh244@gmail.com', 'Pass999#');
INSERT INTO public.khach_hang VALUES ('KH245', 'Vũ Văn Hương', '0515037413', 'khachhang258_kh245@gmail.com', 'An888!');
INSERT INTO public.khach_hang VALUES ('KH246', 'Vũ Gia Tuấn', '0341875800', 'khachhang684_kh246@gmail.com', 'An999#');
INSERT INTO public.khach_hang VALUES ('KH247', 'Đặng Anh Tuấn', '0953763711', 'khachhang300_kh247@gmail.com', 'Yeu999@');
INSERT INTO public.khach_hang VALUES ('KH248', 'Bùi Ngọc Chi', '0566114708', 'khachhang814_kh248@gmail.com', 'Pass999@');
INSERT INTO public.khach_hang VALUES ('KH249', 'Nguyễn Văn Quân', '0807838002', 'khachhang408_kh249@gmail.com', 'Cho2026@');
INSERT INTO public.khach_hang VALUES ('KH250', 'Đỗ Thị Quân', '0915320933', 'khachhang100_kh250@gmail.com', 'Pass2026@');
INSERT INTO public.khach_hang VALUES ('KH251', 'Bùi Ngọc Hương', '0829998846', 'khachhang514_kh251@gmail.com', 'Cho888#');
INSERT INTO public.khach_hang VALUES ('KH252', 'Hoàng Anh Hương', '0546001695', 'khachhang755_kh252@gmail.com', 'Yeu2026@');
INSERT INTO public.khach_hang VALUES ('KH253', 'Đỗ Khánh Dũng', '0341291265', 'khachhang696_kh253@gmail.com', 'Yeu888!');
INSERT INTO public.khach_hang VALUES ('KH254', 'Nguyễn Gia Nam', '0704447829', 'khachhang511_kh254@gmail.com', 'Yeu123@');
INSERT INTO public.khach_hang VALUES ('KH255', 'Nguyễn Văn Khôi', '0860263357', 'khachhang706_kh255@gmail.com', 'Pass888@');
INSERT INTO public.khach_hang VALUES ('KH256', 'Phan Hoàng Linh', '0322973079', 'khachhang756_kh256@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH257', 'Đặng Hoàng Dũng', '0757120243', 'khachhang425_kh257@gmail.com', 'An123@');
INSERT INTO public.khach_hang VALUES ('KH258', 'Trần Văn Chi', '0558015606', 'khachhang832_kh258@gmail.com', 'An999!');
INSERT INTO public.khach_hang VALUES ('KH259', 'Đặng Hoàng Quân', '0880351736', 'khachhang268_kh259@gmail.com', 'An2026#');
INSERT INTO public.khach_hang VALUES ('KH260', 'Hoàng Anh Bình', '0801448383', 'khachhang528_kh260@gmail.com', 'An2026!');
INSERT INTO public.khach_hang VALUES ('KH261', 'Bùi Ngọc Thảo', '0996376722', 'khachhang145_kh261@gmail.com', 'An888#');
INSERT INTO public.khach_hang VALUES ('KH262', 'Phạm Minh Linh', '0577782616', 'khachhang995_kh262@gmail.com', 'Yeu2026#');
INSERT INTO public.khach_hang VALUES ('KH263', 'Vũ Ngọc Linh', '0858104783', 'khachhang235_kh263@gmail.com', 'Cho123!');
INSERT INTO public.khach_hang VALUES ('KH264', 'Hoàng Thị Nam', '0319422764', 'khachhang821_kh264@gmail.com', 'An123#');
INSERT INTO public.khach_hang VALUES ('KH265', 'Bùi Gia Nam', '0550334651', 'khachhang631_kh265@gmail.com', 'Pass2026#');
INSERT INTO public.khach_hang VALUES ('KH266', 'Phan Ngọc Bình', '0336141205', 'khachhang343_kh266@gmail.com', 'An888#');
INSERT INTO public.khach_hang VALUES ('KH267', 'Phan Anh Nam', '0917002431', 'khachhang144_kh267@gmail.com', 'Cho2026#');
INSERT INTO public.khach_hang VALUES ('KH268', 'Lê Anh Tuấn', '0935410963', 'khachhang992_kh268@gmail.com', 'Yeu999@');
INSERT INTO public.khach_hang VALUES ('KH269', 'Nguyễn Hoàng Tuấn', '0705735660', 'khachhang107_kh269@gmail.com', 'Yeu2026#');
INSERT INTO public.khach_hang VALUES ('KH270', 'Phạm Thanh Hương', '0570801226', 'khachhang766_kh270@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH271', 'Lê Ngọc Tuấn', '0319641829', 'khachhang271_kh271@gmail.com', 'Pass2026@');
INSERT INTO public.khach_hang VALUES ('KH272', 'Phạm Ngọc Quân', '0952834949', 'khachhang976_kh272@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH273', 'Bùi Anh Linh', '0882857543', 'khachhang906_kh273@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH274', 'Hoàng Văn An', '0574472544', 'khachhang309_kh274@gmail.com', 'Yeu999@');
INSERT INTO public.khach_hang VALUES ('KH275', 'Nguyễn Anh Bình', '0327922622', 'khachhang378_kh275@gmail.com', 'Pass2026@');
INSERT INTO public.khach_hang VALUES ('KH276', 'Phan Văn Quân', '0844906995', 'khachhang338_kh276@gmail.com', 'Yeu123!');
INSERT INTO public.khach_hang VALUES ('KH277', 'Trần Ngọc Nam', '0561543568', 'khachhang154_kh277@gmail.com', 'Cho2026@');
INSERT INTO public.khach_hang VALUES ('KH278', 'Bùi Anh Nam', '0894538675', 'khachhang857_kh278@gmail.com', 'Yeu2026@');
INSERT INTO public.khach_hang VALUES ('KH279', 'Trần Hoàng Chi', '0942490776', 'khachhang184_kh279@gmail.com', 'An999@');
INSERT INTO public.khach_hang VALUES ('KH280', 'Đỗ Văn Bình', '0344257616', 'khachhang876_kh280@gmail.com', 'Pass888!');
INSERT INTO public.khach_hang VALUES ('KH281', 'Trần Anh Khôi', '0836182744', 'khachhang794_kh281@gmail.com', 'Yeu123!');
INSERT INTO public.khach_hang VALUES ('KH282', 'Trần Khánh Thảo', '0710201577', 'khachhang743_kh282@gmail.com', 'Cho123#');
INSERT INTO public.khach_hang VALUES ('KH283', 'Hoàng Hoàng Thảo', '0824280302', 'khachhang668_kh283@gmail.com', 'Yeu888!');
INSERT INTO public.khach_hang VALUES ('KH284', 'Nguyễn Ngọc Em', '0885005930', 'khachhang719_kh284@gmail.com', 'Cho999@');
INSERT INTO public.khach_hang VALUES ('KH285', 'Lê Thanh Chi', '0874778139', 'khachhang248_kh285@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH286', 'Lê Ngọc Thảo', '0799407282', 'khachhang732_kh286@gmail.com', 'Pass999#');
INSERT INTO public.khach_hang VALUES ('KH287', 'Nguyễn Anh Thảo', '0583462706', 'khachhang813_kh287@gmail.com', 'An888#');
INSERT INTO public.khach_hang VALUES ('KH288', 'Nguyễn Ngọc Linh', '0593108123', 'khachhang808_kh288@gmail.com', 'An123!');
INSERT INTO public.khach_hang VALUES ('KH289', 'Đỗ Thanh Bình', '0933939567', 'khachhang512_kh289@gmail.com', 'Yeu888@');
INSERT INTO public.khach_hang VALUES ('KH290', 'Hoàng Hoàng Bình', '0577808573', 'khachhang631_kh290@gmail.com', 'An999#');
INSERT INTO public.khach_hang VALUES ('KH291', 'Vũ Hoàng Dũng', '0977103698', 'khachhang689_kh291@gmail.com', 'Pass888#');
INSERT INTO public.khach_hang VALUES ('KH292', 'Bùi Anh Khôi', '0703700841', 'khachhang217_kh292@gmail.com', 'Pass123@');
INSERT INTO public.khach_hang VALUES ('KH293', 'Bùi Gia Linh', '0815928710', 'khachhang753_kh293@gmail.com', 'Yeu999#');
INSERT INTO public.khach_hang VALUES ('KH294', 'Phạm Thị Thảo', '0978178268', 'khachhang971_kh294@gmail.com', 'An2026@');
INSERT INTO public.khach_hang VALUES ('KH295', 'Phạm Văn Dũng', '0370814007', 'khachhang191_kh295@gmail.com', 'An2026@');
INSERT INTO public.khach_hang VALUES ('KH296', 'Trần Anh Thảo', '0933164989', 'khachhang331_kh296@gmail.com', 'Pass2026@');
INSERT INTO public.khach_hang VALUES ('KH297', 'Vũ Thị Thảo', '0802241362', 'khachhang785_kh297@gmail.com', 'Cho2026@');
INSERT INTO public.khach_hang VALUES ('KH298', 'Phạm Minh Thảo', '0837019841', 'khachhang930_kh298@gmail.com', 'Cho999#');
INSERT INTO public.khach_hang VALUES ('KH299', 'Phạm Văn Quân', '0562630363', 'khachhang774_kh299@gmail.com', 'Yeu2026@');
INSERT INTO public.khach_hang VALUES ('KH300', 'Hoàng Văn Em', '0582016254', 'khachhang214_kh300@gmail.com', 'Yeu123#');
INSERT INTO public.khach_hang VALUES ('KH301', 'Lê Nguyễn Minh Triết', '0817238929', 'lenguyenminhtriet2077@gmail.com', 'minhtriet123');


--
-- TOC entry 5078 (class 0 OID 17127)
-- Dependencies: 223
-- Data for Name: lich_hen; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.lich_hen VALUES ('LH001', 'BN001', 'DV006', 'NV025', '2025-11-22 08:23:57', '2025-11-22 21:19:57', '2025-11-22 22:44:57', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH002', 'BN002', 'DV005', 'NV008', '2026-01-29 10:04:10', '2026-01-30 21:34:10', '2026-01-30 22:34:10', 'Số 519, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH003', 'BN003', 'DV006', 'NV025', '2025-12-18 18:37:26', '2025-12-19 19:04:26', '2025-12-19 20:33:26', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH004', 'BN004', 'DV002', 'NV012', '2025-05-23 23:46:22', '2025-05-24 20:21:22', '2025-05-24 21:16:22', 'Số 660, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH005', 'BN005', 'DV010', 'NV043', '2026-01-27 03:47:54', '2026-01-27 16:24:54', '2026-01-27 16:58:54', 'Số 368, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH006', 'BN006', 'DV006', 'NV008', '2025-10-15 04:05:42', '2025-10-17 00:09:42', '2025-10-17 01:36:42', 'Số 262, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH007', 'BN007', 'DV003', 'NV004', '2025-05-16 01:06:07', '2025-05-18 00:52:07', '2025-05-18 01:29:07', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH008', 'BN008', 'DV002', 'NV028', '2025-11-03 03:45:57', '2025-11-03 16:22:57', '2025-11-03 17:23:57', 'Số 403, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH009', 'BN009', 'DV003', 'NV012', '2025-12-16 15:35:26', '2025-12-18 04:55:26', '2025-12-18 05:42:26', 'Số 872, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH010', 'BN010', 'DV008', 'NV007', '2025-08-03 16:17:09', '2025-08-04 18:13:09', '2025-08-04 18:43:09', 'Số 936, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH011', 'BN011', 'DV004', 'NV031', '2025-05-24 08:14:43', '2025-05-26 02:01:43', '2025-05-26 03:27:43', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH012', 'BN012', 'DV008', 'NV029', '2025-12-03 03:34:13', '2025-12-04 13:24:13', '2025-12-04 13:56:13', 'Số 645, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH013', 'BN013', 'DV006', 'NV028', '2026-03-27 08:36:57', '2026-03-28 09:43:57', '2026-03-28 10:37:57', 'Số 176, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH014', 'BN014', 'DV003', 'NV030', '2026-03-08 07:12:05', '2026-03-10 07:48:05', '2026-03-10 08:42:05', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH015', 'BN015', 'DV003', 'NV035', '2025-05-03 09:52:54', '2025-05-04 17:29:54', '2025-05-04 18:04:54', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH016', 'BN016', 'DV004', 'NV048', '2025-07-05 16:17:40', '2025-07-07 10:52:40', '2025-07-07 12:12:40', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH017', 'BN017', 'DV003', 'NV037', '2025-07-15 00:22:22', '2025-07-16 17:20:22', '2025-07-16 18:47:22', 'Số 198, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH018', 'BN018', 'DV002', 'NV006', '2025-11-28 05:41:32', '2025-11-29 07:51:32', '2025-11-29 08:36:32', 'Số 328, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH019', 'BN019', 'DV002', 'NV035', '2025-05-14 13:37:17', '2025-05-16 10:11:17', '2025-05-16 11:24:17', 'Số 27, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH020', 'BN020', 'DV004', 'NV013', '2025-06-06 18:08:23', '2025-06-08 16:19:23', '2025-06-08 17:16:23', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH021', 'BN021', 'DV002', 'NV034', '2026-02-08 18:07:59', '2026-02-10 16:38:59', '2026-02-10 17:16:59', 'Số 70, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH022', 'BN022', 'DV001', 'NV013', '2026-01-30 15:54:29', '2026-01-31 18:15:29', '2026-01-31 19:39:29', 'Số 713, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH023', 'BN023', 'DV008', 'NV024', '2025-12-28 04:29:20', '2025-12-29 18:56:20', '2025-12-29 20:07:20', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH024', 'BN024', 'DV004', 'NV038', '2025-08-20 23:38:53', '2025-08-22 05:30:53', '2025-08-22 06:48:53', 'Số 679, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH025', 'BN025', 'DV010', 'NV035', '2025-07-02 17:39:20', '2025-07-03 12:33:20', '2025-07-03 13:07:20', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH026', 'BN026', 'DV002', 'NV032', '2025-04-06 07:06:54', '2025-04-08 08:00:54', '2025-04-08 08:32:54', 'Số 93, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH027', 'BN027', 'DV003', 'NV020', '2025-06-30 06:51:51', '2025-06-30 21:04:51', '2025-06-30 22:04:51', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH028', 'BN028', 'DV008', 'NV015', '2026-02-12 02:00:56', '2026-02-13 11:53:56', '2026-02-13 12:26:56', 'Số 370, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH029', 'BN029', 'DV004', 'NV021', '2025-02-21 01:18:51', '2025-02-22 12:59:51', '2025-02-22 14:25:51', 'Số 797, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH030', 'BN030', 'DV007', 'NV014', '2025-07-28 08:11:32', '2025-07-30 08:52:32', '2025-07-30 09:32:32', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH031', 'BN031', 'DV003', 'NV012', '2025-02-19 09:36:30', '2025-02-20 00:50:30', '2025-02-20 01:33:30', 'Số 584, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH032', 'BN032', 'DV006', 'NV010', '2025-04-30 06:38:11', '2025-05-01 22:24:11', '2025-05-01 23:29:11', 'Số 628, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH033', 'BN033', 'DV002', 'NV046', '2026-02-24 04:50:11', '2026-02-25 19:39:11', '2026-02-25 20:18:11', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH034', 'BN034', 'DV006', 'NV009', '2025-01-04 07:04:48', '2025-01-05 06:05:48', '2025-01-05 07:21:48', 'Số 740, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH035', 'BN035', 'DV002', 'NV009', '2025-12-14 00:27:41', '2025-12-14 18:54:41', '2025-12-14 19:37:41', 'Số 423, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH036', 'BN036', 'DV006', 'NV020', '2026-01-02 03:11:28', '2026-01-03 02:05:28', '2026-01-03 03:23:28', 'Số 960, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH037', 'BN037', 'DV009', 'NV040', '2026-01-10 14:42:59', '2026-01-11 21:06:59', '2026-01-11 21:59:59', 'Số 591, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH038', 'BN038', 'DV002', 'NV024', '2025-03-10 01:09:23', '2025-03-11 02:34:23', '2025-03-11 03:33:23', 'Số 825, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH039', 'BN039', 'DV004', 'NV048', '2025-08-28 14:32:29', '2025-08-29 15:31:29', '2025-08-29 16:41:29', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH040', 'BN040', 'DV005', 'NV016', '2025-04-13 06:01:19', '2025-04-13 19:44:19', '2025-04-13 20:59:19', 'Số 541, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH041', 'BN041', 'DV004', 'NV025', '2026-03-06 00:46:39', '2026-03-07 11:50:39', '2026-03-07 13:03:39', 'Số 824, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH042', 'BN042', 'DV001', 'NV034', '2025-02-26 18:50:42', '2025-02-27 18:56:42', '2025-02-27 19:37:42', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH043', 'BN043', 'DV008', 'NV035', '2026-02-19 21:22:35', '2026-02-21 21:45:35', '2026-02-21 22:52:35', 'Số 21, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH044', 'BN044', 'DV005', 'NV022', '2025-03-30 02:10:54', '2025-03-31 16:14:54', '2025-03-31 17:29:54', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH045', 'BN045', 'DV007', 'NV029', '2025-07-15 19:19:46', '2025-07-17 03:22:46', '2025-07-17 03:59:46', 'Số 970, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH046', 'BN046', 'DV003', 'NV018', '2025-09-17 14:50:06', '2025-09-18 23:39:06', '2025-09-19 01:02:06', 'Số 15, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH047', 'BN047', 'DV008', 'NV001', '2025-10-29 06:57:21', '2025-10-30 09:05:21', '2025-10-30 10:12:21', 'Số 70, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH048', 'BN048', 'DV001', 'NV021', '2025-04-17 13:28:26', '2025-04-18 16:22:26', '2025-04-18 17:09:26', 'Số 477, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH049', 'BN049', 'DV010', 'NV046', '2025-11-08 01:47:45', '2025-11-09 00:48:45', '2025-11-09 01:51:45', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH050', 'BN050', 'DV007', 'NV012', '2026-02-12 07:08:09', '2026-02-13 12:40:09', '2026-02-13 13:40:09', 'Số 393, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH051', 'BN051', 'DV004', 'NV045', '2025-02-25 19:20:51', '2025-02-27 09:21:51', '2025-02-27 10:05:51', 'Số 754, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH052', 'BN052', 'DV003', 'NV030', '2025-06-02 05:37:48', '2025-06-04 06:04:48', '2025-06-04 07:06:48', 'Số 314, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH053', 'BN053', 'DV001', 'NV034', '2025-10-14 21:34:43', '2025-10-15 19:10:43', '2025-10-15 19:42:43', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH054', 'BN054', 'DV010', 'NV046', '2025-09-13 15:27:49', '2025-09-15 00:04:49', '2025-09-15 01:00:49', 'Số 622, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH055', 'BN055', 'DV009', 'NV009', '2025-02-20 10:29:37', '2025-02-22 02:36:37', '2025-02-22 03:20:37', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH056', 'BN056', 'DV004', 'NV006', '2025-04-14 15:00:49', '2025-04-16 07:31:49', '2025-04-16 08:31:49', 'Số 354, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH057', 'BN057', 'DV006', 'NV005', '2026-03-05 01:41:55', '2026-03-06 11:30:55', '2026-03-06 12:35:55', 'Số 725, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH058', 'BN058', 'DV005', 'NV015', '2025-07-05 20:32:47', '2025-07-07 17:48:47', '2025-07-07 19:14:47', 'Số 115, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH059', 'BN059', 'DV001', 'NV001', '2025-07-15 18:58:46', '2025-07-17 07:04:46', '2025-07-17 08:21:46', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH060', 'BN060', 'DV006', 'NV043', '2025-09-22 07:22:56', '2025-09-24 06:36:56', '2025-09-24 07:14:56', 'Số 774, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH061', 'BN061', 'DV007', 'NV015', '2025-06-08 01:29:42', '2025-06-09 01:22:42', '2025-06-09 01:57:42', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH062', 'BN062', 'DV002', 'NV034', '2025-02-20 14:36:12', '2025-02-21 21:11:12', '2025-02-21 22:24:12', 'Số 880, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH063', 'BN063', 'DV007', 'NV002', '2025-07-29 05:41:48', '2025-07-31 04:26:48', '2025-07-31 04:56:48', 'Số 464, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH064', 'BN064', 'DV001', 'NV040', '2025-08-23 03:22:03', '2025-08-24 19:24:03', '2025-08-24 20:36:03', 'Số 22, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH065', 'BN065', 'DV010', 'NV007', '2025-07-23 21:47:13', '2025-07-25 05:09:13', '2025-07-25 05:57:13', 'Số 598, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH066', 'BN066', 'DV002', 'NV044', '2025-11-29 09:53:29', '2025-12-01 04:22:29', '2025-12-01 05:13:29', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH067', 'BN067', 'DV008', 'NV005', '2025-08-23 20:50:33', '2025-08-25 13:50:33', '2025-08-25 15:12:33', 'Số 462, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH068', 'BN068', 'DV010', 'NV032', '2025-12-02 15:17:28', '2025-12-03 12:05:28', '2025-12-03 13:28:28', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH069', 'BN069', 'DV007', 'NV016', '2026-03-30 16:41:51', '2026-03-31 11:36:51', '2026-03-31 12:12:51', 'Số 645, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH070', 'BN070', 'DV005', 'NV030', '2025-02-16 07:35:12', '2025-02-17 17:50:12', '2025-02-17 18:20:12', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH071', 'BN071', 'DV009', 'NV050', '2025-04-27 18:12:34', '2025-04-28 15:21:34', '2025-04-28 16:37:34', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH072', 'BN072', 'DV007', 'NV041', '2025-06-20 18:56:53', '2025-06-21 17:41:53', '2025-06-21 18:27:53', 'Số 572, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH073', 'BN073', 'DV005', 'NV009', '2025-06-14 12:29:31', '2025-06-15 09:30:31', '2025-06-15 10:51:31', 'Số 904, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH074', 'BN074', 'DV003', 'NV030', '2025-03-08 03:28:25', '2025-03-09 11:49:25', '2025-03-09 13:13:25', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH075', 'BN075', 'DV009', 'NV008', '2025-05-11 11:27:28', '2025-05-12 01:28:28', '2025-05-12 02:05:28', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH076', 'BN076', 'DV006', 'NV015', '2026-01-07 00:39:41', '2026-01-07 15:13:41', '2026-01-07 16:07:41', 'Số 306, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH077', 'BN077', 'DV007', 'NV038', '2025-11-27 00:20:55', '2025-11-27 22:02:55', '2025-11-27 23:31:55', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH078', 'BN078', 'DV006', 'NV039', '2025-07-14 09:18:04', '2025-07-16 09:26:04', '2025-07-16 10:25:04', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH079', 'BN079', 'DV003', 'NV014', '2026-03-20 05:08:24', '2026-03-21 05:28:24', '2026-03-21 05:58:24', 'Số 100, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH080', 'BN080', 'DV007', 'NV049', '2025-06-21 10:59:41', '2025-06-22 21:04:41', '2025-06-22 21:53:41', 'Số 158, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH081', 'BN081', 'DV004', 'NV042', '2025-05-27 06:36:49', '2025-05-29 00:03:49', '2025-05-29 01:12:49', 'Số 109, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH082', 'BN082', 'DV010', 'NV021', '2025-05-10 05:41:32', '2025-05-11 09:11:32', '2025-05-11 10:20:32', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH083', 'BN083', 'DV009', 'NV004', '2025-05-13 23:13:36', '2025-05-14 20:16:36', '2025-05-14 20:46:36', 'Số 806, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH084', 'BN084', 'DV003', 'NV015', '2025-06-22 15:19:37', '2025-06-23 22:48:37', '2025-06-23 23:24:37', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH085', 'BN085', 'DV009', 'NV029', '2025-04-09 01:04:59', '2025-04-10 13:03:59', '2025-04-10 13:44:59', 'Số 205, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH086', 'BN086', 'DV010', 'NV009', '2025-01-09 16:23:13', '2025-01-10 21:09:13', '2025-01-10 22:39:13', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH087', 'BN087', 'DV001', 'NV033', '2026-03-10 03:42:29', '2026-03-11 03:56:29', '2026-03-11 04:47:29', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH088', 'BN088', 'DV008', 'NV029', '2026-03-08 07:00:06', '2026-03-09 07:40:06', '2026-03-09 08:27:06', 'Số 208, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH089', 'BN089', 'DV005', 'NV009', '2025-10-21 16:39:12', '2025-10-23 01:29:12', '2025-10-23 02:24:12', 'Số 419, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH090', 'BN090', 'DV002', 'NV049', '2025-12-14 20:43:36', '2025-12-15 17:29:36', '2025-12-15 18:44:36', 'Số 928, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH091', 'BN091', 'DV008', 'NV032', '2025-05-18 22:29:22', '2025-05-20 20:52:22', '2025-05-20 22:05:22', 'Số 251, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH092', 'BN092', 'DV003', 'NV023', '2025-11-25 03:01:25', '2025-11-26 06:32:25', '2025-11-26 07:19:25', 'Số 909, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH093', 'BN093', 'DV003', 'NV001', '2026-03-20 08:08:53', '2026-03-21 16:21:53', '2026-03-21 17:14:53', 'Số 293, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH094', 'BN094', 'DV003', 'NV017', '2025-03-02 10:00:15', '2025-03-03 08:40:15', '2025-03-03 09:17:15', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH095', 'BN095', 'DV010', 'NV025', '2025-10-26 21:21:52', '2025-10-28 07:01:52', '2025-10-28 08:04:52', 'Số 828, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH096', 'BN096', 'DV007', 'NV046', '2025-01-07 07:33:56', '2025-01-08 13:21:56', '2025-01-08 14:20:56', 'Số 714, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH097', 'BN097', 'DV003', 'NV045', '2025-02-15 04:49:06', '2025-02-15 17:08:06', '2025-02-15 17:46:06', 'Số 861, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH098', 'BN098', 'DV005', 'NV003', '2026-01-31 21:17:42', '2026-02-02 19:08:42', '2026-02-02 20:37:42', 'Số 772, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH099', 'BN099', 'DV009', 'NV013', '2026-01-22 02:52:11', '2026-01-23 02:09:11', '2026-01-23 03:15:11', 'Số 861, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH100', 'BN100', 'DV009', 'NV042', '2025-07-08 10:35:46', '2025-07-10 00:56:46', '2025-07-10 01:52:46', 'Số 592, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH101', 'BN101', 'DV009', 'NV007', '2026-01-18 09:22:55', '2026-01-20 03:45:55', '2026-01-20 04:16:55', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH102', 'BN102', 'DV002', 'NV026', '2026-02-08 19:56:44', '2026-02-10 12:18:44', '2026-02-10 13:33:44', 'Số 964, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH103', 'BN103', 'DV009', 'NV027', '2025-06-07 17:33:14', '2025-06-08 14:25:14', '2025-06-08 15:17:14', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH104', 'BN104', 'DV004', 'NV015', '2025-08-29 01:46:01', '2025-08-29 23:13:01', '2025-08-30 00:11:01', 'Số 786, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH105', 'BN105', 'DV005', 'NV035', '2025-02-27 07:01:55', '2025-02-28 13:13:55', '2025-02-28 14:10:55', 'Số 498, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH106', 'BN106', 'DV009', 'NV020', '2025-05-03 13:03:24', '2025-05-04 05:44:24', '2025-05-04 06:26:24', 'Số 761, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH107', 'BN107', 'DV009', 'NV047', '2025-08-29 15:24:11', '2025-08-30 03:47:11', '2025-08-30 04:39:11', 'Số 530, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH108', 'BN108', 'DV006', 'NV019', '2025-01-28 20:56:38', '2025-01-30 00:19:38', '2025-01-30 01:14:38', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH109', 'BN109', 'DV005', 'NV026', '2025-07-15 15:18:48', '2025-07-16 12:11:48', '2025-07-16 13:03:48', 'Số 722, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH110', 'BN110', 'DV008', 'NV022', '2025-03-06 16:03:26', '2025-03-08 13:33:26', '2025-03-08 14:39:26', 'Số 824, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH111', 'BN111', 'DV008', 'NV050', '2025-07-27 12:48:34', '2025-07-28 04:06:34', '2025-07-28 05:07:34', 'Số 840, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH112', 'BN112', 'DV009', 'NV021', '2025-05-18 02:42:32', '2025-05-18 19:44:32', '2025-05-18 20:15:32', 'Số 841, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH113', 'BN113', 'DV008', 'NV032', '2026-03-12 23:57:29', '2026-03-13 12:42:29', '2026-03-13 13:44:29', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH114', 'BN114', 'DV005', 'NV004', '2025-01-19 04:56:50', '2025-01-19 22:57:50', '2025-01-19 23:59:50', 'Số 336, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH115', 'BN115', 'DV005', 'NV015', '2025-10-05 21:41:35', '2025-10-07 00:52:35', '2025-10-07 01:23:35', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH116', 'BN116', 'DV008', 'NV002', '2025-06-19 11:52:27', '2025-06-20 21:48:27', '2025-06-20 22:50:27', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH117', 'BN117', 'DV002', 'NV018', '2026-03-13 17:56:38', '2026-03-15 05:42:38', '2026-03-15 06:48:38', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH118', 'BN118', 'DV006', 'NV010', '2026-02-25 05:57:39', '2026-02-27 03:01:39', '2026-02-27 04:04:39', 'Số 277, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH119', 'BN119', 'DV001', 'NV020', '2025-08-24 05:20:00', '2025-08-25 03:11:00', '2025-08-25 03:59:00', 'Số 232, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH120', 'BN120', 'DV007', 'NV039', '2026-01-02 01:17:55', '2026-01-03 16:34:55', '2026-01-03 17:44:55', 'Số 224, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH121', 'BN121', 'DV010', 'NV047', '2025-01-29 10:09:10', '2025-01-30 14:22:10', '2025-01-30 15:33:10', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH122', 'BN122', 'DV010', 'NV022', '2025-05-05 14:25:22', '2025-05-07 00:09:22', '2025-05-07 01:32:22', 'Số 635, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH123', 'BN123', 'DV004', 'NV011', '2026-03-30 11:29:16', '2026-04-01 01:05:16', '2026-04-01 01:46:16', 'Số 454, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH124', 'BN124', 'DV001', 'NV004', '2025-08-01 22:54:27', '2025-08-03 05:11:27', '2025-08-03 05:54:27', 'Số 186, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH125', 'BN125', 'DV010', 'NV047', '2025-11-15 22:12:53', '2025-11-16 10:55:53', '2025-11-16 12:01:53', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH126', 'BN126', 'DV009', 'NV042', '2025-04-19 18:42:45', '2025-04-20 11:03:45', '2025-04-20 12:32:45', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH127', 'BN127', 'DV003', 'NV048', '2025-11-11 19:37:39', '2025-11-12 23:27:39', '2025-11-13 00:22:39', 'Số 93, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH128', 'BN128', 'DV007', 'NV025', '2026-01-25 21:57:30', '2026-01-27 06:18:30', '2026-01-27 06:48:30', 'Số 873, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH129', 'BN129', 'DV002', 'NV041', '2025-09-26 20:27:46', '2025-09-27 23:39:46', '2025-09-28 00:48:46', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH130', 'BN130', 'DV004', 'NV008', '2025-04-02 10:45:00', '2025-04-03 01:24:00', '2025-04-03 02:51:00', 'Số 47, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH131', 'BN131', 'DV005', 'NV014', '2025-02-25 01:19:22', '2025-02-25 13:50:22', '2025-02-25 14:30:22', 'Số 637, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH132', 'BN132', 'DV009', 'NV031', '2025-11-02 10:26:31', '2025-11-04 09:57:31', '2025-11-04 10:34:31', 'Số 806, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH133', 'BN133', 'DV009', 'NV007', '2025-10-20 07:10:41', '2025-10-21 15:23:41', '2025-10-21 16:10:41', 'Số 300, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH134', 'BN134', 'DV009', 'NV036', '2025-01-20 22:19:11', '2025-01-22 21:59:11', '2025-01-22 22:45:11', 'Số 953, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH135', 'BN135', 'DV006', 'NV003', '2026-04-07 18:05:03', '2026-04-09 02:00:03', '2026-04-09 02:41:03', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Chờ', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH136', 'BN136', 'DV007', 'NV017', '2025-12-21 23:16:02', '2025-12-23 02:21:02', '2025-12-23 03:04:02', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH137', 'BN137', 'DV001', 'NV039', '2026-01-26 03:42:28', '2026-01-27 09:40:28', '2026-01-27 11:10:28', 'Số 381, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH138', 'BN138', 'DV003', 'NV007', '2026-03-06 09:11:48', '2026-03-07 16:36:48', '2026-03-07 17:07:48', 'Số 35, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH139', 'BN139', 'DV010', 'NV047', '2025-08-04 09:11:50', '2025-08-05 13:44:50', '2025-08-05 14:24:50', 'Số 632, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH140', 'BN140', 'DV004', 'NV033', '2026-03-11 01:20:07', '2026-03-12 04:39:07', '2026-03-12 05:46:07', 'Số 983, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH141', 'BN141', 'DV009', 'NV048', '2025-12-25 08:41:15', '2025-12-26 21:22:15', '2025-12-26 22:20:15', 'Số 704, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH142', 'BN142', 'DV008', 'NV023', '2025-11-17 00:52:31', '2025-11-19 00:59:31', '2025-11-19 02:16:31', 'Số 545, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH143', 'BN143', 'DV001', 'NV016', '2025-06-07 09:24:41', '2025-06-09 09:54:41', '2025-06-09 10:37:41', 'Số 259, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH144', 'BN144', 'DV003', 'NV008', '2026-03-25 10:38:22', '2026-03-25 23:43:22', '2026-03-26 01:02:22', 'Số 291, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH145', 'BN145', 'DV010', 'NV040', '2025-06-03 23:37:29', '2025-06-04 22:02:29', '2025-06-04 23:05:29', 'Số 525, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH146', 'BN146', 'DV006', 'NV014', '2025-12-14 23:06:20', '2025-12-16 01:59:20', '2025-12-16 02:58:20', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH147', 'BN147', 'DV009', 'NV021', '2025-09-29 22:53:04', '2025-09-30 18:44:04', '2025-09-30 19:52:04', 'Số 979, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH148', 'BN148', 'DV010', 'NV026', '2026-01-31 16:12:38', '2026-02-01 11:41:38', '2026-02-01 12:22:38', 'Số 305, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH149', 'BN149', 'DV001', 'NV001', '2025-11-17 23:56:52', '2025-11-19 04:53:52', '2025-11-19 05:52:52', 'Số 202, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH150', 'BN150', 'DV010', 'NV001', '2025-08-28 11:57:57', '2025-08-29 04:43:57', '2025-08-29 05:20:57', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH151', 'BN151', 'DV007', 'NV006', '2026-02-17 07:49:45', '2026-02-18 08:58:45', '2026-02-18 09:53:45', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH152', 'BN152', 'DV010', 'NV012', '2025-07-01 21:52:00', '2025-07-02 16:55:00', '2025-07-02 17:43:00', 'Số 394, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH153', 'BN153', 'DV008', 'NV007', '2025-07-01 23:43:49', '2025-07-03 21:48:49', '2025-07-03 22:21:49', 'Số 978, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH154', 'BN154', 'DV008', 'NV041', '2026-04-01 15:38:25', '2026-04-02 19:08:25', '2026-04-02 19:55:25', 'Số 739, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH155', 'BN155', 'DV005', 'NV014', '2025-08-03 12:11:15', '2025-08-04 11:23:15', '2025-08-04 12:32:15', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH156', 'BN156', 'DV002', 'NV008', '2025-09-20 12:50:02', '2025-09-21 05:35:02', '2025-09-21 07:02:02', 'Số 133, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH157', 'BN157', 'DV010', 'NV049', '2025-06-16 02:24:29', '2025-06-16 17:41:29', '2025-06-16 18:45:29', 'Số 926, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH158', 'BN158', 'DV008', 'NV013', '2025-03-09 08:00:37', '2025-03-10 15:12:37', '2025-03-10 16:26:37', 'Số 41, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH159', 'BN159', 'DV001', 'NV014', '2026-01-22 06:56:48', '2026-01-23 11:05:48', '2026-01-23 11:42:48', 'Số 146, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH160', 'BN160', 'DV003', 'NV047', '2025-03-03 10:55:49', '2025-03-05 06:36:49', '2025-03-05 07:58:49', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH161', 'BN161', 'DV002', 'NV042', '2025-01-12 07:52:23', '2025-01-14 05:44:23', '2025-01-14 06:46:23', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH162', 'BN162', 'DV008', 'NV007', '2025-05-18 18:24:07', '2025-05-19 09:48:07', '2025-05-19 10:30:07', 'Số 912, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH163', 'BN163', 'DV002', 'NV007', '2026-01-13 01:14:43', '2026-01-14 19:21:43', '2026-01-14 20:00:43', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH164', 'BN164', 'DV010', 'NV015', '2025-07-20 11:44:55', '2025-07-22 04:50:55', '2025-07-22 06:04:55', 'Số 613, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH165', 'BN165', 'DV005', 'NV045', '2025-03-08 13:46:39', '2025-03-10 06:27:39', '2025-03-10 07:43:39', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH166', 'BN166', 'DV005', 'NV024', '2025-07-15 09:44:25', '2025-07-16 23:57:25', '2025-07-17 00:37:25', 'Số 986, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH167', 'BN167', 'DV003', 'NV009', '2025-01-29 10:55:42', '2025-01-30 06:31:42', '2025-01-30 07:33:42', 'Số 706, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH168', 'BN168', 'DV001', 'NV035', '2025-01-18 20:15:12', '2025-01-19 16:18:12', '2025-01-19 17:40:12', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH169', 'BN169', 'DV008', 'NV049', '2025-01-05 12:09:30', '2025-01-06 10:44:30', '2025-01-06 12:13:30', 'Số 292, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH170', 'BN170', 'DV007', 'NV009', '2025-11-07 10:36:46', '2025-11-09 08:50:46', '2025-11-09 10:10:46', 'Số 255, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH171', 'BN171', 'DV003', 'NV022', '2025-06-18 05:52:44', '2025-06-18 21:56:44', '2025-06-18 22:32:44', 'Số 729, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH172', 'BN172', 'DV003', 'NV040', '2025-01-01 21:34:46', '2025-01-03 06:39:46', '2025-01-03 07:18:46', 'Số 177, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH173', 'BN173', 'DV001', 'NV017', '2026-03-27 01:18:38', '2026-03-28 23:50:38', '2026-03-29 01:16:38', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH174', 'BN174', 'DV001', 'NV050', '2025-02-12 13:35:47', '2025-02-14 01:19:47', '2025-02-14 02:36:47', 'Số 421, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH175', 'BN175', 'DV008', 'NV008', '2025-01-28 17:27:21', '2025-01-30 14:59:21', '2025-01-30 15:38:21', 'Số 147, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH176', 'BN176', 'DV007', 'NV036', '2025-09-30 02:12:40', '2025-10-02 00:08:40', '2025-10-02 01:19:40', 'Số 158, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH177', 'BN177', 'DV010', 'NV008', '2025-05-05 08:36:00', '2025-05-06 19:23:00', '2025-05-06 20:45:00', 'Số 285, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH178', 'BN178', 'DV006', 'NV023', '2025-12-14 14:19:19', '2025-12-15 03:59:19', '2025-12-15 05:18:19', 'Số 481, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH179', 'BN179', 'DV005', 'NV006', '2025-08-24 18:14:59', '2025-08-25 15:24:59', '2025-08-25 16:41:59', 'Số 320, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH180', 'BN180', 'DV010', 'NV037', '2026-03-08 04:28:45', '2026-03-08 18:41:45', '2026-03-08 19:42:45', 'Số 897, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH181', 'BN181', 'DV003', 'NV016', '2025-01-13 06:24:21', '2025-01-14 22:40:21', '2025-01-14 23:42:21', 'Số 701, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH182', 'BN182', 'DV008', 'NV031', '2026-04-07 01:09:36', '2026-04-08 15:34:36', '2026-04-08 16:42:36', 'Số 218, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Chờ', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH183', 'BN183', 'DV010', 'NV029', '2025-02-23 06:38:39', '2025-02-24 11:39:39', '2025-02-24 12:44:39', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH184', 'BN184', 'DV003', 'NV026', '2025-06-20 19:00:39', '2025-06-22 08:56:39', '2025-06-22 09:35:39', 'Số 122, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH185', 'BN185', 'DV003', 'NV018', '2025-04-22 16:20:44', '2025-04-23 10:36:44', '2025-04-23 12:01:44', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH186', 'BN186', 'DV001', 'NV021', '2025-04-14 15:16:04', '2025-04-15 07:49:04', '2025-04-15 08:57:04', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH187', 'BN187', 'DV007', 'NV011', '2025-10-25 21:39:07', '2025-10-27 11:03:07', '2025-10-27 11:57:07', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH188', 'BN188', 'DV007', 'NV004', '2026-02-28 10:20:11', '2026-03-01 06:13:11', '2026-03-01 07:37:11', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH189', 'BN189', 'DV005', 'NV042', '2025-04-12 16:41:04', '2025-04-13 12:24:04', '2025-04-13 13:02:04', 'Số 169, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH190', 'BN190', 'DV005', 'NV038', '2025-09-19 09:49:12', '2025-09-20 04:02:12', '2025-09-20 04:45:12', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH191', 'BN191', 'DV010', 'NV034', '2026-01-25 11:17:08', '2026-01-26 20:50:08', '2026-01-26 21:44:08', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH192', 'BN192', 'DV005', 'NV022', '2025-05-12 11:13:47', '2025-05-13 15:21:47', '2025-05-13 15:56:47', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH193', 'BN193', 'DV004', 'NV014', '2025-03-28 11:44:17', '2025-03-30 05:06:17', '2025-03-30 06:05:17', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH194', 'BN194', 'DV006', 'NV012', '2025-05-26 18:56:36', '2025-05-28 07:07:36', '2025-05-28 07:56:36', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH195', 'BN195', 'DV001', 'NV007', '2025-05-19 21:48:28', '2025-05-21 14:29:28', '2025-05-21 15:40:28', 'Số 509, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH196', 'BN196', 'DV003', 'NV036', '2025-09-04 12:38:43', '2025-09-05 14:00:43', '2025-09-05 15:09:43', 'Số 439, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH197', 'BN197', 'DV006', 'NV046', '2025-08-19 11:51:54', '2025-08-21 10:07:54', '2025-08-21 10:57:54', 'Số 580, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH198', 'BN198', 'DV007', 'NV028', '2026-02-08 23:13:13', '2026-02-10 20:10:13', '2026-02-10 21:08:13', 'Số 288, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH199', 'BN199', 'DV008', 'NV004', '2025-08-29 23:05:42', '2025-08-31 10:39:42', '2025-08-31 11:16:42', 'Số 94, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH200', 'BN200', 'DV009', 'NV008', '2026-01-19 11:38:54', '2026-01-20 14:51:54', '2026-01-20 15:35:54', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH201', 'BN201', 'DV001', 'NV028', '2025-02-11 19:25:20', '2025-02-13 19:10:20', '2025-02-13 20:13:20', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH202', 'BN202', 'DV005', 'NV032', '2026-03-12 20:53:51', '2026-03-13 15:10:51', '2026-03-13 16:15:51', 'Số 733, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH203', 'BN203', 'DV003', 'NV024', '2026-02-04 19:37:22', '2026-02-06 08:30:22', '2026-02-06 09:53:22', 'Số 132, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH204', 'BN204', 'DV008', 'NV012', '2025-07-19 01:15:22', '2025-07-20 00:13:22', '2025-07-20 01:28:22', 'Số 498, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH205', 'BN205', 'DV005', 'NV013', '2025-12-01 15:27:40', '2025-12-03 01:10:40', '2025-12-03 01:58:40', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH206', 'BN206', 'DV007', 'NV005', '2025-04-30 14:20:57', '2025-05-01 09:28:57', '2025-05-01 10:57:57', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH207', 'BN207', 'DV006', 'NV034', '2025-04-17 13:10:03', '2025-04-18 08:04:03', '2025-04-18 08:36:03', 'Số 213, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH208', 'BN208', 'DV006', 'NV009', '2025-05-11 13:53:07', '2025-05-13 03:43:07', '2025-05-13 04:31:07', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH209', 'BN209', 'DV008', 'NV021', '2026-04-09 04:01:36', '2026-04-10 13:16:36', '2026-04-10 14:25:36', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Chờ', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH210', 'BN210', 'DV002', 'NV038', '2025-05-19 14:27:22', '2025-05-21 09:30:22', '2025-05-21 10:07:22', 'Số 662, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH211', 'BN211', 'DV002', 'NV033', '2025-12-18 18:25:15', '2025-12-19 12:00:15', '2025-12-19 12:59:15', 'Số 489, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH212', 'BN212', 'DV006', 'NV039', '2025-10-21 16:00:57', '2025-10-23 02:25:57', '2025-10-23 03:04:57', 'Số 228, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH213', 'BN213', 'DV004', 'NV012', '2025-10-06 17:17:33', '2025-10-07 07:05:33', '2025-10-07 07:45:33', 'Số 763, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH214', 'BN214', 'DV005', 'NV017', '2025-01-29 17:08:08', '2025-01-31 17:43:08', '2025-01-31 18:55:08', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH215', 'BN215', 'DV010', 'NV005', '2025-07-08 23:57:20', '2025-07-10 12:58:20', '2025-07-10 13:45:20', 'Số 940, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH216', 'BN216', 'DV010', 'NV024', '2025-07-23 19:42:22', '2025-07-24 13:11:22', '2025-07-24 13:50:22', 'Số 336, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH217', 'BN217', 'DV001', 'NV009', '2025-04-22 08:09:49', '2025-04-23 02:07:49', '2025-04-23 02:47:49', 'Số 175, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH218', 'BN218', 'DV007', 'NV026', '2025-11-18 05:07:07', '2025-11-20 05:09:07', '2025-11-20 06:27:07', 'Số 958, Đường Lê Lợi, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH219', 'BN219', 'DV003', 'NV002', '2025-09-25 00:48:20', '2025-09-27 01:09:20', '2025-09-27 02:06:20', 'Số 181, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH220', 'BN220', 'DV008', 'NV042', '2025-06-05 10:58:36', '2025-06-06 10:15:36', '2025-06-06 11:20:36', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH221', 'BN221', 'DV002', 'NV044', '2025-08-27 14:26:58', '2025-08-28 16:23:58', '2025-08-28 17:48:58', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH222', 'BN222', 'DV010', 'NV001', '2025-03-15 09:18:59', '2025-03-16 20:55:59', '2025-03-16 22:23:59', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH223', 'BN223', 'DV009', 'NV042', '2025-07-30 02:32:29', '2025-07-31 19:28:29', '2025-07-31 20:23:29', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH224', 'BN224', 'DV010', 'NV041', '2025-11-03 20:02:22', '2025-11-05 10:53:22', '2025-11-05 11:29:22', 'Số 480, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH225', 'BN225', 'DV006', 'NV048', '2026-03-08 00:24:43', '2026-03-08 22:44:43', '2026-03-09 00:11:43', 'Số 122, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH226', 'BN226', 'DV009', 'NV041', '2025-01-28 16:08:18', '2025-01-29 22:03:18', '2025-01-29 23:10:18', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH227', 'BN227', 'DV003', 'NV006', '2025-09-11 21:04:01', '2025-09-12 18:52:01', '2025-09-12 19:28:01', 'Số 980, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH228', 'BN228', 'DV003', 'NV004', '2025-05-08 17:26:27', '2025-05-09 11:43:27', '2025-05-09 12:53:27', 'Số 525, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH229', 'BN229', 'DV010', 'NV004', '2025-12-13 23:58:41', '2025-12-15 07:30:41', '2025-12-15 08:05:41', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH230', 'BN230', 'DV003', 'NV002', '2025-07-15 02:44:14', '2025-07-16 12:36:14', '2025-07-16 13:30:14', 'Số 681, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH231', 'BN231', 'DV010', 'NV040', '2026-01-11 07:50:19', '2026-01-12 14:59:19', '2026-01-12 15:51:19', 'Số 44, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH232', 'BN232', 'DV007', 'NV001', '2025-05-23 19:23:42', '2025-05-24 15:12:42', '2025-05-24 15:49:42', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH233', 'BN233', 'DV009', 'NV049', '2025-11-17 13:23:27', '2025-11-18 05:37:27', '2025-11-18 07:04:27', 'Số 30, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH234', 'BN234', 'DV005', 'NV026', '2025-08-30 05:18:01', '2025-08-31 05:42:01', '2025-08-31 06:28:01', 'Số 752, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH235', 'BN235', 'DV004', 'NV023', '2025-03-18 22:52:14', '2025-03-20 18:20:14', '2025-03-20 19:44:14', 'Số 572, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH236', 'BN236', 'DV006', 'NV031', '2025-01-10 22:35:48', '2025-01-12 09:30:48', '2025-01-12 10:27:48', 'Số 49, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH237', 'BN237', 'DV001', 'NV031', '2026-02-06 08:17:22', '2026-02-08 07:33:22', '2026-02-08 08:13:22', 'Số 608, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH238', 'BN238', 'DV001', 'NV008', '2025-07-13 15:49:02', '2025-07-15 13:34:02', '2025-07-15 14:27:02', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH239', 'BN239', 'DV002', 'NV032', '2025-10-06 10:30:38', '2025-10-07 19:50:38', '2025-10-07 20:27:38', 'Số 446, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH240', 'BN240', 'DV003', 'NV047', '2025-08-20 04:24:54', '2025-08-21 17:49:54', '2025-08-21 18:19:54', 'Số 733, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH241', 'BN241', 'DV005', 'NV033', '2025-01-20 10:09:28', '2025-01-22 07:10:28', '2025-01-22 08:38:28', 'Số 193, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH242', 'BN242', 'DV001', 'NV030', '2025-05-01 04:24:56', '2025-05-02 22:52:56', '2025-05-02 23:50:56', 'Số 71, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH243', 'BN243', 'DV005', 'NV007', '2025-01-08 14:31:50', '2025-01-10 09:06:50', '2025-01-10 09:41:50', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH244', 'BN244', 'DV004', 'NV008', '2025-12-01 20:12:32', '2025-12-03 00:52:32', '2025-12-03 01:41:32', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH245', 'BN245', 'DV010', 'NV036', '2026-02-20 16:16:14', '2026-02-21 21:04:14', '2026-02-21 22:16:14', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH246', 'BN246', 'DV002', 'NV045', '2026-02-06 12:43:36', '2026-02-08 06:06:36', '2026-02-08 06:40:36', 'Số 591, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH247', 'BN247', 'DV003', 'NV049', '2025-07-25 19:09:16', '2025-07-27 18:32:16', '2025-07-27 19:37:16', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH248', 'BN248', 'DV009', 'NV014', '2025-01-30 14:29:57', '2025-02-01 12:12:57', '2025-02-01 12:45:57', 'Số 21, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH249', 'BN249', 'DV010', 'NV042', '2025-11-21 06:27:21', '2025-11-22 23:34:21', '2025-11-23 00:49:21', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH250', 'BN250', 'DV006', 'NV015', '2026-03-26 13:37:15', '2026-03-27 19:37:15', '2026-03-27 20:27:15', 'Số 660, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH251', 'BN251', 'DV004', 'NV003', '2025-01-14 13:09:30', '2025-01-16 08:50:30', '2025-01-16 09:37:30', 'Số 609, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH252', 'BN252', 'DV003', 'NV049', '2026-02-28 01:55:10', '2026-02-28 18:30:10', '2026-02-28 19:47:10', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH253', 'BN253', 'DV006', 'NV006', '2025-05-27 04:20:51', '2025-05-28 05:54:51', '2025-05-28 06:43:51', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH254', 'BN254', 'DV001', 'NV027', '2025-03-17 09:38:27', '2025-03-19 07:02:27', '2025-03-19 07:38:27', 'Số 652, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH255', 'BN255', 'DV008', 'NV018', '2025-08-10 15:08:22', '2025-08-11 13:35:22', '2025-08-11 14:18:22', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH256', 'BN256', 'DV002', 'NV006', '2025-06-16 06:53:07', '2025-06-18 06:15:07', '2025-06-18 07:39:07', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH257', 'BN257', 'DV008', 'NV047', '2025-03-10 22:11:07', '2025-03-12 11:28:07', '2025-03-12 12:50:07', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH258', 'BN258', 'DV010', 'NV002', '2025-06-24 09:26:48', '2025-06-25 17:13:48', '2025-06-25 18:08:48', 'Số 801, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH259', 'BN259', 'DV009', 'NV001', '2026-02-20 18:12:54', '2026-02-21 10:20:54', '2026-02-21 11:31:54', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH260', 'BN260', 'DV010', 'NV012', '2025-07-10 08:02:41', '2025-07-12 03:47:41', '2025-07-12 05:04:41', 'Số 966, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH261', 'BN261', 'DV005', 'NV007', '2025-12-12 17:34:53', '2025-12-13 19:29:53', '2025-12-13 20:59:53', 'Số 231, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH262', 'BN262', 'DV001', 'NV001', '2025-10-02 18:24:15', '2025-10-03 22:47:15', '2025-10-03 23:41:15', 'Số 96, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH263', 'BN263', 'DV010', 'NV006', '2025-01-21 04:11:06', '2025-01-22 03:20:06', '2025-01-22 04:43:06', 'Số 315, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH264', 'BN264', 'DV002', 'NV021', '2025-11-07 05:12:31', '2025-11-08 16:45:31', '2025-11-08 17:33:31', 'Số 116, Đường Lê Lợi, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH265', 'BN265', 'DV003', 'NV046', '2026-02-08 01:36:25', '2026-02-09 15:00:25', '2026-02-09 15:46:25', 'Số 81, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH266', 'BN266', 'DV009', 'NV035', '2026-01-07 20:50:55', '2026-01-09 02:56:55', '2026-01-09 03:58:55', 'Số 177, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH267', 'BN267', 'DV007', 'NV037', '2025-05-16 21:17:26', '2025-05-18 21:17:26', '2025-05-18 21:55:26', 'Số 473, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH268', 'BN268', 'DV006', 'NV019', '2025-11-14 04:57:33', '2025-11-16 02:48:33', '2025-11-16 03:33:33', 'Số 352, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH269', 'BN269', 'DV007', 'NV035', '2025-11-09 01:57:20', '2025-11-10 19:10:20', '2025-11-10 20:06:20', 'Số 885, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH270', 'BN270', 'DV004', 'NV010', '2025-05-14 02:56:08', '2025-05-16 03:53:08', '2025-05-16 04:52:08', 'Số 948, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH271', 'BN271', 'DV008', 'NV045', '2025-01-30 01:57:41', '2025-01-31 04:45:41', '2025-01-31 05:44:41', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH272', 'BN272', 'DV003', 'NV031', '2025-03-14 05:01:05', '2025-03-15 23:07:05', '2025-03-16 00:07:05', 'Số 19, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH273', 'BN273', 'DV009', 'NV037', '2025-02-05 04:17:04', '2025-02-05 19:36:04', '2025-02-05 21:01:04', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH274', 'BN274', 'DV008', 'NV048', '2026-02-13 01:51:29', '2026-02-14 19:09:29', '2026-02-14 20:38:29', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH275', 'BN275', 'DV009', 'NV028', '2025-07-04 16:55:09', '2025-07-05 15:17:09', '2025-07-05 16:28:09', 'Số 368, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH276', 'BN276', 'DV008', 'NV014', '2025-08-20 20:40:48', '2025-08-21 18:17:48', '2025-08-21 18:57:48', 'Số 101, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH277', 'BN277', 'DV001', 'NV003', '2025-07-25 10:06:45', '2025-07-27 09:10:45', '2025-07-27 10:28:45', 'Số 372, Đường Nguyễn Huệ, Quận 3, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH278', 'BN278', 'DV003', 'NV001', '2025-07-16 01:23:29', '2025-07-16 21:44:29', '2025-07-16 22:26:29', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH279', 'BN279', 'DV007', 'NV028', '2025-07-29 13:17:17', '2025-07-30 21:07:17', '2025-07-30 21:42:17', 'Số 846, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH280', 'BN280', 'DV004', 'NV037', '2025-01-26 02:56:56', '2025-01-27 02:05:56', '2025-01-27 03:16:56', 'Số 564, Đường Nguyễn Huệ, Quận 10, TP. Hồ Chí Minh', 'Đã hủy', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH281', 'BN281', 'DV008', 'NV023', '2025-07-19 01:20:16', '2025-07-20 02:21:16', '2025-07-20 02:57:16', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH282', 'BN282', 'DV004', 'NV010', '2025-02-20 05:23:53', '2025-02-21 20:23:53', '2025-02-21 21:39:53', 'Số 364, Đường Lê Lợi, Quận 10, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH283', 'BN283', 'DV004', 'NV003', '2026-04-01 22:16:55', '2026-04-03 13:25:55', '2026-04-03 13:58:55', 'Số 576, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH284', 'BN284', 'DV005', 'NV037', '2025-05-28 21:12:01', '2025-05-30 07:27:01', '2025-05-30 08:36:01', 'Số 250, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH285', 'BN285', 'DV001', 'NV004', '2025-02-20 19:26:12', '2025-02-22 04:05:12', '2025-02-22 05:11:12', 'Số 610, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH286', 'BN286', 'DV006', 'NV016', '2025-06-01 11:42:05', '2025-06-02 03:13:05', '2025-06-02 04:03:05', 'Số 149, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH287', 'BN287', 'DV002', 'NV031', '2025-09-30 12:36:57', '2025-10-01 01:21:57', '2025-10-01 02:31:57', 'Số 201, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH288', 'BN288', 'DV003', 'NV007', '2025-06-11 23:21:12', '2025-06-13 17:41:12', '2025-06-13 18:28:12', 'Số 120, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH289', 'BN289', 'DV003', 'NV009', '2025-02-12 22:23:48', '2025-02-13 16:11:48', '2025-02-13 17:01:48', 'Số 926, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH290', 'BN290', 'DV009', 'NV038', '2025-12-16 05:03:51', '2025-12-16 23:50:51', '2025-12-17 00:50:51', 'Số 163, Đường Nguyễn Huệ, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH291', 'BN291', 'DV007', 'NV013', '2025-01-16 12:01:28', '2025-01-17 04:50:28', '2025-01-17 05:29:28', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH292', 'BN292', 'DV006', 'NV003', '2025-11-13 07:15:12', '2025-11-15 00:23:12', '2025-11-15 01:15:12', 'Số 677, Đường Nguyễn Huệ, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH293', 'BN293', 'DV001', 'NV002', '2025-08-03 13:55:37', '2025-08-05 00:56:37', '2025-08-05 02:18:37', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH294', 'BN294', 'DV001', 'NV018', '2025-01-02 12:57:45', '2025-01-04 07:37:45', '2025-01-04 08:50:45', 'Số 909, Đường Lê Lợi, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH295', 'BN295', 'DV008', 'NV020', '2025-10-07 11:31:53', '2025-10-09 05:29:53', '2025-10-09 06:29:53', 'Số 745, Đường Lê Lợi, Quận 7, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH296', 'BN296', 'DV008', 'NV016', '2026-03-14 22:08:01', '2026-03-15 10:14:01', '2026-03-15 11:37:01', 'Số 815, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH297', 'BN297', 'DV002', 'NV050', '2026-01-26 11:11:58', '2026-01-27 17:10:58', '2026-01-27 18:40:58', 'Tại bệnh viện (Số 123 Nguyễn Chí Thanh, Quận 5, TP. Hồ Chí Minh)', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH298', 'BN298', 'DV005', 'NV025', '2025-05-08 12:08:11', '2025-05-10 13:01:11', '2025-05-10 14:06:11', 'Số 981, Đường Lê Lợi, Quận 5, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH299', 'BN299', 'DV007', 'NV025', '2025-12-16 17:02:33', '2025-12-18 04:04:33', '2025-12-18 05:02:33', 'Số 924, Đường Nguyễn Huệ, Quận Bình Thạnh, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH300', 'BN300', 'DV001', 'NV047', '2026-03-25 06:34:01', '2026-03-27 03:24:01', '2026-03-27 04:02:01', 'Số 13, Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Hoàn thành', NULL, NULL);
INSERT INTO public.lich_hen VALUES ('LH301', 'BN301', 'DV002', 'NV002', '2026-05-16 08:00:00', '2026-05-16 09:00:00', '2026-05-16 16:52:52.64988', 'Tại bệnh viện', 'Hoàn thành', NULL, NULL);


--
-- TOC entry 5076 (class 0 OID 17102)
-- Dependencies: 221
-- Data for Name: nhan_vien_chuyen_khoa; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV001', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV002', 'CK004');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV003', 'CK003');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV004', 'CK001');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV005', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV006', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV007', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV008', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV009', 'CK007');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV010', 'CK009');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV011', 'CK002');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV012', 'CK008');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV013', 'CK006');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV014', 'CK007');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV015', 'CK009');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV016', 'CK003');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV017', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV018', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV019', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV020', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV021', 'CK008');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV022', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV023', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV024', 'CK002');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV025', 'CK004');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV026', 'CK006');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV027', 'CK001');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV028', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV029', 'CK004');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV030', 'CK002');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV031', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV032', 'CK008');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV033', 'CK007');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV034', 'CK003');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV035', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV036', 'CK006');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV037', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV038', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV039', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV040', 'CK009');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV041', 'CK001');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV042', 'CK006');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV043', 'CK009');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV044', 'CK004');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV045', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV046', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV047', 'CK002');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV048', 'CK001');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV049', 'CK005');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV050', 'CK003');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV051', 'CK007');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV052', 'CK008');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV053', 'CK001');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV054', 'CK002');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV055', 'CK003');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV056', 'CK004');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV057', 'CK006');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV058', 'CK007');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV059', 'CK008');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV060', 'CK009');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV061', 'CK001');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV062', 'CK002');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV063', 'CK003');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV064', 'CK004');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV065', 'CK006');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV066', 'CK007');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV067', 'CK008');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV068', 'CK009');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV069', 'CK001');
INSERT INTO public.nhan_vien_chuyen_khoa VALUES ('NV070', 'CK002');


--
-- TOC entry 5074 (class 0 OID 17079)
-- Dependencies: 219
-- Data for Name: nhan_vien_y_te; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.nhan_vien_y_te VALUES ('NV001', 'Lê Hữu An', '87461717944', '975561794', '1996-11-17', 'Hộ sinh', 'Sẵn sàng', 'CCHN-51458', '2020-01-01', 'Bộ Y tế', '2030-01-01', 8, 3.54);
INSERT INTO public.nhan_vien_y_te VALUES ('NV002', 'Phạm Văn Bình', '45643920393', '901092766', '1963-05-03', 'Bác sĩ', 'Sẵn sàng', 'CCHN-69590', '1986-06-10', 'Sở Y tế TP.HCM', '1996-06-10', 41, 3.77);
INSERT INTO public.nhan_vien_y_te VALUES ('NV003', 'Nguyễn Văn Lan', '71455579610', '742217336', '1991-05-15', 'KTV', 'Đang bận', 'CCHN-77140', '2015-04-06', 'Sở Y tế TP.HCM', '2025-04-06', 13, 4.85);
INSERT INTO public.nhan_vien_y_te VALUES ('NV004', 'Phạm Phương Đức', '70330595648', '980190863', '1984-06-17', 'KTV', 'Đang bận', 'CCHN-82345', '2007-12-30', 'Sở Y tế TP.HCM', '2017-12-30', 20, 4.29);
INSERT INTO public.nhan_vien_y_te VALUES ('NV005', 'Hoàng Phương Hà', '10103285057', '598319494', '1975-05-22', 'Hộ sinh', 'Đang bận', 'CCHN-51974', '1999-05-03', 'Sở Y tế Đồng Nai', '2009-05-03', 29, 3.40);
INSERT INTO public.nhan_vien_y_te VALUES ('NV006', 'Lê Phương Châu', '47764214423', '988413385', '1980-05-09', 'Hộ sinh', 'Đang bận', 'CCHN-48791', '2003-09-11', 'Sở Y tế TP.HCM', '2013-09-11', 24, 3.38);
INSERT INTO public.nhan_vien_y_te VALUES ('NV007', 'Trần Minh Đức', '39845507884', '543440871', '1960-01-09', 'KTV', 'Nghỉ', 'CCHN-13074', '1983-02-13', 'Sở Y tế Đồng Nai', '1993-02-13', 44, 3.40);
INSERT INTO public.nhan_vien_y_te VALUES ('NV008', 'Vũ Minh An', '80311511926', '929947360', '1985-09-11', 'Hộ sinh', 'Sẵn sàng', 'CCHN-67284', '2009-03-26', 'Sở Y tế Đồng Nai', '2019-03-26', 19, 4.04);
INSERT INTO public.nhan_vien_y_te VALUES ('NV009', 'Trần Minh Châu', '52340646487', '544482966', '1998-10-11', 'Điều dưỡng', 'Nghỉ', 'CCHN-96609', '2022-09-23', 'Sở Y tế Bình Dương', '2032-09-23', 6, 3.70);
INSERT INTO public.nhan_vien_y_te VALUES ('NV010', 'Phạm Minh Đức', '20205475479', '962830784', '1997-12-08', 'Điều dưỡng', 'Sẵn sàng', 'CCHN-18807', '2021-02-05', 'Sở Y tế Bình Dương', '2031-02-05', 7, 3.56);
INSERT INTO public.nhan_vien_y_te VALUES ('NV011', 'Trần Minh Lan', '87639120481', '956288797', '1982-01-03', 'Điều dưỡng', 'Nghỉ', 'CCHN-42374', '2005-06-18', 'Sở Y tế Bình Dương', '2015-06-18', 22, 4.59);
INSERT INTO public.nhan_vien_y_te VALUES ('NV012', 'Lê Minh Lan', '19750631044', '796180189', '1976-07-27', 'Điều dưỡng', 'Đang bận', 'CCHN-65923', '1999-10-17', 'Sở Y tế Bình Dương', '2009-10-17', 28, 4.91);
INSERT INTO public.nhan_vien_y_te VALUES ('NV013', 'Phạm Hữu Nam', '86357169028', '305169436', '1984-11-06', 'Bác sĩ', 'Đang bận', 'CCHN-12346', '2008-07-23', 'Bộ Y tế', '2018-07-23', 20, 4.81);
INSERT INTO public.nhan_vien_y_te VALUES ('NV014', 'Vũ Hữu Châu', '49291913736', '798127784', '1962-11-13', 'Bác sĩ', 'Nghỉ', 'CCHN-11257', '1986-06-18', 'Sở Y tế Đồng Nai', '1996-06-18', 42, 3.77);
INSERT INTO public.nhan_vien_y_te VALUES ('NV015', 'Hoàng Minh Nam', '57387870821', '932053143', '1988-03-06', 'KTV', 'Đang bận', 'CCHN-60404', '2011-08-13', 'Sở Y tế TP.HCM', '2021-08-13', 16, 3.91);
INSERT INTO public.nhan_vien_y_te VALUES ('NV016', 'Phạm Minh An', '32829412440', '887046411', '1970-07-23', 'Điều dưỡng', 'Sẵn sàng', 'CCHN-49965', '1994-05-20', 'Sở Y tế TP.HCM', '2004-05-20', 34, 4.76);
INSERT INTO public.nhan_vien_y_te VALUES ('NV017', 'Vũ Minh Châu', '36035750664', '718873225', '1999-02-27', 'Hộ sinh', 'Nghỉ', 'CCHN-55675', '2023-02-14', 'Sở Y tế Bình Dương', '2033-02-14', 5, 4.77);
INSERT INTO public.nhan_vien_y_te VALUES ('NV018', 'Vũ Phương Bình', '66185113008', '785847849', '1992-05-02', 'Hộ sinh', 'Nghỉ', 'CCHN-42515', '2015-08-20', 'Sở Y tế Đồng Nai', '2025-08-20', 12, 2.70);
INSERT INTO public.nhan_vien_y_te VALUES ('NV019', 'Phạm Hữu Nam', '14180260812', '858890551', '1969-08-28', 'Hộ sinh', 'Nghỉ', 'CCHN-44275', '1993-01-21', 'Sở Y tế TP.HCM', '2003-01-21', 35, 4.48);
INSERT INTO public.nhan_vien_y_te VALUES ('NV020', 'Lê Phương Đức', '54266019507', '531327655', '1968-06-27', 'Hộ sinh', 'Đang bận', 'CCHN-50053', '1992-02-06', 'Bộ Y tế', '2002-02-06', 36, 2.53);
INSERT INTO public.nhan_vien_y_te VALUES ('NV021', 'Trần Hữu Bình', '12574503958', '705892775', '1990-10-09', 'KTV', 'Đang bận', 'CCHN-25343', '2013-11-11', 'Bộ Y tế', '2023-11-11', 14, 3.45);
INSERT INTO public.nhan_vien_y_te VALUES ('NV022', 'Nguyễn Hữu Khang', '48415688848', '807773756', '1989-09-04', 'Bác sĩ', 'Nghỉ', 'CCHN-76154', '2013-08-18', 'Sở Y tế TP.HCM', '2023-08-18', 15, 2.37);
INSERT INTO public.nhan_vien_y_te VALUES ('NV023', 'Hoàng Phương An', '57366049697', '970749349', '1990-12-01', 'Hộ sinh', 'Nghỉ', 'CCHN-53208', '2014-01-09', 'Sở Y tế Đồng Nai', '2024-01-09', 14, 2.18);
INSERT INTO public.nhan_vien_y_te VALUES ('NV024', 'Vũ Minh Bình', '18535476764', '302551453', '1994-05-18', 'Bác sĩ', 'Sẵn sàng', 'CCHN-10932', '2017-08-30', 'Sở Y tế Bình Dương', '2027-08-30', 10, 3.82);
INSERT INTO public.nhan_vien_y_te VALUES ('NV025', 'Phạm Thị An', '93486288804', '367502375', '1998-01-12', 'KTV', 'Nghỉ', 'CCHN-43698', '2021-03-03', 'Sở Y tế TP.HCM', '2031-03-03', 6, 4.78);
INSERT INTO public.nhan_vien_y_te VALUES ('NV026', 'Hoàng Thị Bình', '66846994205', '741899702', '1984-02-17', 'Bác sĩ', 'Nghỉ', 'CCHN-48482', '2007-04-26', 'Sở Y tế TP.HCM', '2017-04-26', 20, 3.20);
INSERT INTO public.nhan_vien_y_te VALUES ('NV027', 'Vũ Phương Đức', '95967629149', '825156932', '1960-10-24', 'Điều dưỡng', 'Sẵn sàng', 'CCHN-72009', '1984-08-16', 'Bộ Y tế', '1994-08-16', 44, 4.23);
INSERT INTO public.nhan_vien_y_te VALUES ('NV028', 'Hoàng Minh Nam', '51480436657', '901078766', '1984-03-17', 'Hộ sinh', 'Đang bận', 'CCHN-74807', '2007-09-24', 'Bộ Y tế', '2017-09-24', 20, 3.27);
INSERT INTO public.nhan_vien_y_te VALUES ('NV029', 'Trần Phương Hà', '57776947962', '312548398', '1995-03-22', 'Bác sĩ', 'Sẵn sàng', 'CCHN-17639', '2018-10-31', 'Sở Y tế Bình Dương', '2028-10-31', 9, 2.29);
INSERT INTO public.nhan_vien_y_te VALUES ('NV030', 'Vũ Ngọc An', '80775951856', '514021918', '1965-05-17', 'Bác sĩ', 'Đang bận', 'CCHN-42532', '1988-10-22', 'Bộ Y tế', '1998-10-22', 39, 5.00);
INSERT INTO public.nhan_vien_y_te VALUES ('NV031', 'Phạm Hữu Khang', '50541052274', '958760320', '1999-09-26', 'Hộ sinh', 'Nghỉ', 'CCHN-27910', '2023-06-30', 'Bộ Y tế', '2033-06-30', 5, 4.94);
INSERT INTO public.nhan_vien_y_te VALUES ('NV032', 'Lê Phương Khang', '17850355015', '367956706', '1973-05-14', 'Điều dưỡng', 'Sẵn sàng', 'CCHN-49772', '1997-02-24', 'Sở Y tế Đồng Nai', '2007-02-24', 31, 4.19);
INSERT INTO public.nhan_vien_y_te VALUES ('NV033', 'Nguyễn Hữu Lan', '79433652971', '515397298', '1969-04-29', 'Bác sĩ', 'Đang bận', 'CCHN-30487', '1993-01-12', 'Sở Y tế TP.HCM', '2003-01-12', 35, 2.23);
INSERT INTO public.nhan_vien_y_te VALUES ('NV034', 'Lê Ngọc Khang', '48370297570', '540922021', '1996-08-28', 'Bác sĩ', 'Sẵn sàng', 'CCHN-22258', '2019-09-26', 'Sở Y tế Đồng Nai', '2029-09-26', 8, 3.69);
INSERT INTO public.nhan_vien_y_te VALUES ('NV035', 'Hoàng Thị Nam', '73624113066', '372865240', '1975-10-14', 'Bác sĩ', 'Sẵn sàng', 'CCHN-73092', '1999-08-21', 'Sở Y tế Bình Dương', '2009-08-21', 29, 4.24);
INSERT INTO public.nhan_vien_y_te VALUES ('NV036', 'Phạm Ngọc Khang', '84953277219', '576494730', '1965-12-30', 'Điều dưỡng', 'Nghỉ', 'CCHN-80390', '1989-11-18', 'Sở Y tế TP.HCM', '1999-11-18', 39, 4.47);
INSERT INTO public.nhan_vien_y_te VALUES ('NV037', 'Vũ Thị Bình', '42528897531', '892030411', '1986-06-18', 'Hộ sinh', 'Đang bận', 'CCHN-98774', '2009-09-03', 'Bộ Y tế', '2019-09-03', 18, 3.20);
INSERT INTO public.nhan_vien_y_te VALUES ('NV038', 'Phạm Thị Nam', '47182186933', '380271908', '1987-06-05', 'Hộ sinh', 'Đang bận', 'CCHN-41209', '2010-10-07', 'Sở Y tế Bình Dương', '2020-10-07', 17, 4.03);
INSERT INTO public.nhan_vien_y_te VALUES ('NV039', 'Phạm Thị Bình', '17404446527', '808838242', '1960-05-25', 'Hộ sinh', 'Sẵn sàng', 'CCHN-52925', '1983-08-28', 'Bộ Y tế', '1993-08-28', 44, 3.08);
INSERT INTO public.nhan_vien_y_te VALUES ('NV040', 'Trần Thị Khang', '99307007541', '511235510', '1995-01-07', 'Điều dưỡng', 'Đang bận', 'CCHN-65770', '2018-11-01', 'Sở Y tế Bình Dương', '2028-11-01', 9, 4.39);
INSERT INTO public.nhan_vien_y_te VALUES ('NV041', 'Trần Minh Nam', '34092512729', '815316980', '1997-02-22', 'Bác sĩ', 'Đang bận', 'CCHN-31706', '2020-03-29', 'Bộ Y tế', '2030-03-29', 7, 2.93);
INSERT INTO public.nhan_vien_y_te VALUES ('NV042', 'Nguyễn Minh Nam', '17800611297', '313808598', '1960-12-13', 'Bác sĩ', 'Sẵn sàng', 'CCHN-29184', '1984-05-03', 'Sở Y tế Bình Dương', '1994-05-03', 44, 3.50);
INSERT INTO public.nhan_vien_y_te VALUES ('NV043', 'Trần Hữu Bình', '15328284332', '757444578', '1973-07-24', 'KTV', 'Nghỉ', 'CCHN-44447', '1997-02-03', 'Bộ Y tế', '2007-02-03', 31, 3.11);
INSERT INTO public.nhan_vien_y_te VALUES ('NV044', 'Lê Hữu Đức', '23507886513', '334465024', '1998-09-15', 'KTV', 'Sẵn sàng', 'CCHN-90748', '2022-05-27', 'Bộ Y tế', '2032-05-27', 6, 4.51);
INSERT INTO public.nhan_vien_y_te VALUES ('NV045', 'Vũ Hữu Hà', '49306771296', '388123014', '1997-03-19', 'Bác sĩ', 'Đang bận', 'CCHN-83120', '2020-08-30', 'Bộ Y tế', '2030-08-30', 7, 3.60);
INSERT INTO public.nhan_vien_y_te VALUES ('NV046', 'Phạm Thị Nam', '52664265544', '358933490', '1984-12-22', 'Hộ sinh', 'Đang bận', 'CCHN-10449', '2008-11-18', 'Sở Y tế Đồng Nai', '2018-11-18', 20, 4.14);
INSERT INTO public.nhan_vien_y_te VALUES ('NV047', 'Trần Phương Nam', '41731542689', '501844658', '1993-10-01', 'Bác sĩ', 'Đang bận', 'CCHN-89150', '2017-03-19', 'Bộ Y tế', '2027-03-19', 11, 3.47);
INSERT INTO public.nhan_vien_y_te VALUES ('NV048', 'Phạm Văn Nam', '63051392512', '865962531', '1965-08-21', 'Điều dưỡng', 'Sẵn sàng', 'CCHN-18012', '1989-08-19', 'Sở Y tế Đồng Nai', '1999-08-19', 39, 3.64);
INSERT INTO public.nhan_vien_y_te VALUES ('NV049', 'Trần Hữu Bình', '58967630537', '959371564', '1986-11-30', 'Hộ sinh', 'Đang bận', 'CCHN-19332', '2010-09-30', 'Bộ Y tế', '2020-09-30', 18, 2.23);
INSERT INTO public.nhan_vien_y_te VALUES ('NV050', 'Phạm Văn Hà', '68668978058', '573170572', '1992-12-18', 'KTV', 'Đang bận', 'CCHN-43019', '2016-09-25', 'Sở Y tế TP.HCM', '2026-09-25', 12, 2.42);
INSERT INTO public.nhan_vien_y_te VALUES ('NV051', 'Đặng Anh Hùng', '377079700442', '0975294551', '1984-10-06', 'Điều dưỡng', 'Nghỉ', 'CCHN-12893', '2023-04-19', 'Sở Y tế Đồng Nai', '2033-04-16', 32, 3.51);
INSERT INTO public.nhan_vien_y_te VALUES ('NV052', 'Lê Phương Anh', '059419912131', '0908398121', '1982-12-13', 'Điều dưỡng', 'Đang bận', 'CCHN-81582', '2023-02-25', 'Sở Y tế Hà Nội', '2033-02-22', 40, 4.66);
INSERT INTO public.nhan_vien_y_te VALUES ('NV053', 'Bùi Hoàng Dũng', '622784482370', '0802852448', '1995-10-10', 'Điều dưỡng', 'Sẵn sàng', 'CCHN-61774', '2017-06-22', 'Sở Y tế Đà Nẵng', '2027-06-20', 17, 4.77);
INSERT INTO public.nhan_vien_y_te VALUES ('NV054', 'Hoàng Thị Bình', '737637613706', '0600145832', '1981-12-22', 'Điều dưỡng', 'Đang bận', 'CCHN-94058', '2023-09-15', 'Sở Y tế Cần Thơ', '2033-09-12', 32, 3.70);
INSERT INTO public.nhan_vien_y_te VALUES ('NV055', 'Lê Thị Dũng', '144269624770', '0814882459', '1977-12-04', 'Bác sĩ', 'Đang bận', 'CCHN-52609', '2016-01-18', 'Sở Y tế Bình Dương', '2026-01-15', 18, 3.11);
INSERT INTO public.nhan_vien_y_te VALUES ('NV056', 'Nguyễn Hữu Quân', '463696213648', '0509972581', '1981-01-17', 'Điều dưỡng', 'Nghỉ', 'CCHN-26154', '2019-03-19', 'Sở Y tế TP.HCM', '2029-03-16', 28, 4.87);
INSERT INTO public.nhan_vien_y_te VALUES ('NV057', 'Hoàng Thị Dũng', '495444157927', '0806301734', '1969-12-19', 'Bác sĩ', 'Sẵn sàng', 'CCHN-26889', '2019-11-07', 'Sở Y tế Cần Thơ', '2029-11-04', 22, 2.82);
INSERT INTO public.nhan_vien_y_te VALUES ('NV058', 'Trần Anh Tâm', '938876409475', '0734096480', '1990-05-01', 'Điều dưỡng', 'Đang bận', 'CCHN-31109', '2016-03-29', 'Sở Y tế Đà Nẵng', '2026-03-27', 25, 3.86);
INSERT INTO public.nhan_vien_y_te VALUES ('NV059', 'Nguyễn Đức Giang', '647990734698', '0806130614', '1981-10-24', 'Bác sĩ', 'Đang bận', 'CCHN-34960', '2020-12-10', 'Sở Y tế Bình Dương', '2030-12-08', 30, 3.49);
INSERT INTO public.nhan_vien_y_te VALUES ('NV060', 'Lê Minh Hà', '578239402718', '0847680573', '1987-02-23', 'Điều dưỡng', 'Nghỉ', 'CCHN-42437', '2012-11-28', 'Sở Y tế Cần Thơ', '2022-11-26', 29, 4.59);
INSERT INTO public.nhan_vien_y_te VALUES ('NV061', 'Vũ Hữu Nam', '303750433568', '0642169640', '1971-06-20', 'Điều dưỡng', 'Đang bận', 'CCHN-67765', '2017-03-02', 'Sở Y tế TP.HCM', '2027-02-28', 10, 4.65);
INSERT INTO public.nhan_vien_y_te VALUES ('NV062', 'Đặng Kim Em', '160062383230', '0690769726', '1973-03-26', 'Điều dưỡng', 'Sẵn sàng', 'CCHN-90905', '2016-10-31', 'Sở Y tế Bình Dương', '2026-10-29', 12, 2.19);
INSERT INTO public.nhan_vien_y_te VALUES ('NV063', 'Vũ Đức Hà', '843400124778', '0893635065', '1961-04-07', 'KTV', 'Nghỉ', 'CCHN-17156', '2013-10-23', 'Bộ Y tế', '2023-10-21', 6, 4.95);
INSERT INTO public.nhan_vien_y_te VALUES ('NV064', 'Nguyễn Hữu Hùng', '401989534462', '0513012633', '1994-08-25', 'KTV', 'Sẵn sàng', 'CCHN-63190', '2019-07-30', 'Sở Y tế Đồng Nai', '2029-07-27', 25, 2.85);
INSERT INTO public.nhan_vien_y_te VALUES ('NV065', 'Nguyễn Ngọc Anh', '746358155668', '0965941117', '1996-11-06', 'Điều dưỡng', 'Sẵn sàng', 'CCHN-15178', '2017-03-05', 'Sở Y tế Đà Nẵng', '2027-03-03', 21, 2.74);
INSERT INTO public.nhan_vien_y_te VALUES ('NV066', 'Hoàng Hoàng Lan', '686423254639', '0638413020', '1982-04-06', 'Bác sĩ', 'Đang bận', 'CCHN-97337', '2015-05-01', 'Sở Y tế Đà Nẵng', '2025-04-28', 2, 2.13);
INSERT INTO public.nhan_vien_y_te VALUES ('NV067', 'Nguyễn Ngọc Hùng', '347851204883', '0771497952', '1998-11-06', 'KTV', 'Sẵn sàng', 'CCHN-93577', '2023-04-12', 'Sở Y tế Đồng Nai', '2033-04-09', 20, 2.06);
INSERT INTO public.nhan_vien_y_te VALUES ('NV068', 'Vũ Anh Hà', '090807978149', '0766675986', '1985-05-19', 'Bác sĩ', 'Đang bận', 'CCHN-65880', '2019-10-15', 'Sở Y tế Đà Nẵng', '2029-10-12', 29, 4.51);
INSERT INTO public.nhan_vien_y_te VALUES ('NV069', 'Trần Hữu Xuân', '681103622048', '0301545755', '1970-12-18', 'KTV', 'Đang bận', 'CCHN-22320', '2010-12-12', 'Sở Y tế Cần Thơ', '2020-12-09', 6, 3.65);
INSERT INTO public.nhan_vien_y_te VALUES ('NV070', 'Hoàng Hoàng Bình', '807327131330', '0956691802', '1960-01-23', 'KTV', 'Nghỉ', 'CCHN-32565', '2016-11-15', 'Sở Y tế Đà Nẵng', '2026-11-13', 29, 3.29);


--
-- TOC entry 5079 (class 0 OID 17166)
-- Dependencies: 224
-- Data for Name: vat_tu_y_te; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.vat_tu_y_te VALUES ('VT007', 'Thuốc xịt Salbutamol', 85000.00, 'Chai', 233);
INSERT INTO public.vat_tu_y_te VALUES ('VT011', 'Men vi sinh', 150000.00, 'Hộp', 101);
INSERT INTO public.vat_tu_y_te VALUES ('VT021', 'Thuốc kháng histamin Loratadin', 20000.00, 'Vỉ', 136);
INSERT INTO public.vat_tu_y_te VALUES ('VT010', 'Thuốc kháng virus Tenofovir', 450000.00, 'Hộp', 201);
INSERT INTO public.vat_tu_y_te VALUES ('VT015', 'Viên sắt Sulfat', 95000.00, 'Hộp', 148);
INSERT INTO public.vat_tu_y_te VALUES ('VT026', 'Găng tay vô trùng', 65000.00, 'Hộp', 265);
INSERT INTO public.vat_tu_y_te VALUES ('VT012', 'Dịch truyền đạm', 200000.00, 'Chai', 229);
INSERT INTO public.vat_tu_y_te VALUES ('VT008', 'Máy xông khí dung', 850000.00, 'Cái', 139);
INSERT INTO public.vat_tu_y_te VALUES ('VT020', 'Băng thun y tế', 25000.00, 'Cuộn', 127);
INSERT INTO public.vat_tu_y_te VALUES ('VT018', 'Canxi Nano', 220000.00, 'Hộp', 158);
INSERT INTO public.vat_tu_y_te VALUES ('VT004', 'Thuốc Amlodipine', 35000.00, 'Vỉ', 247);
INSERT INTO public.vat_tu_y_te VALUES ('VT017', 'Thuốc Colchicine', 110000.00, 'Hộp', 200);
INSERT INTO public.vat_tu_y_te VALUES ('VT023', 'Nước muối sinh lý 0.9%', 15000.00, 'Chai', 133);
INSERT INTO public.vat_tu_y_te VALUES ('VT001', 'Vitamin tổng hợp', 150000.00, 'Hộp', 256);
INSERT INTO public.vat_tu_y_te VALUES ('VT030', 'Thuốc hỗ trợ giấc ngủ Melatonin', 310000.00, 'Hộp', 198);
INSERT INTO public.vat_tu_y_te VALUES ('VT029', 'Vitamin nhóm B', 135000.00, 'Hộp', 215);
INSERT INTO public.vat_tu_y_te VALUES ('VT028', 'Thuốc an thần nhẹ', 280000.00, 'Hộp', 203);
INSERT INTO public.vat_tu_y_te VALUES ('VT022', 'Thuốc bôi chống ngứa', 40000.00, 'Tuýp', 101);
INSERT INTO public.vat_tu_y_te VALUES ('VT002', 'Insulin tiêm', 250000.00, 'Lọ', 137);
INSERT INTO public.vat_tu_y_te VALUES ('VT013', 'Bơm kim tiêm 5ml', 3000.00, 'Cái', 117);
INSERT INTO public.vat_tu_y_te VALUES ('VT016', 'Thuốc Atorvastatin', 160000.00, 'Hộp', 170);
INSERT INTO public.vat_tu_y_te VALUES ('VT019', 'Thuốc giảm đau Meloxicam', 45000.00, 'Vỉ', 223);
INSERT INTO public.vat_tu_y_te VALUES ('VT025', 'Dây truyền hóa chất', 85000.00, 'Bộ', 208);
INSERT INTO public.vat_tu_y_te VALUES ('VT032', 'Gói bù nước Oresol', 3000.00, 'Gói', 192);
INSERT INTO public.vat_tu_y_te VALUES ('VT031', 'Paracetamol 500mg', 15000.00, 'Vỉ', 220);
INSERT INTO public.vat_tu_y_te VALUES ('VT027', 'Quần áo phẫu thuật', 120000.00, 'Bộ', 261);
INSERT INTO public.vat_tu_y_te VALUES ('VT009', 'Bình thở oxy', 1200000.00, 'Bình', 188);
INSERT INTO public.vat_tu_y_te VALUES ('VT005', 'Máy đo huyết áp', 650000.00, 'Cái', 239);
INSERT INTO public.vat_tu_y_te VALUES ('VT024', 'Bơm tiêm điện', 1500000.00, 'Cái', 128);
INSERT INTO public.vat_tu_y_te VALUES ('VT014', 'Thuốc tan sỏi Rowatinex', 320000.00, 'Hộp', 152);
INSERT INTO public.vat_tu_y_te VALUES ('VT006', 'Thuốc trợ tim Digoxin', 180000.00, 'Hộp', 184);
INSERT INTO public.vat_tu_y_te VALUES ('VT003', 'Thuốc Metformin', 120000.00, 'Hộp', 261);


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

CREATE TRIGGER trg_ai_phantichcamxuc BEFORE INSERT OR UPDATE ON public.danh_gia FOR EACH ROW EXECUTE FUNCTION public.trg_ai_phantichcamxuc();


--
-- TOC entry 4920 (class 2620 OID 25464)
-- Name: ket_qua_kham trg_ai_phantichsuckhoe; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ai_phantichsuckhoe BEFORE INSERT OR UPDATE ON public.ket_qua_kham FOR EACH ROW EXECUTE FUNCTION public.trg_ai_phantichsuckhoe();


--
-- TOC entry 4916 (class 2620 OID 17243)
-- Name: benh_nhan trg_gioihanhosobenhnhan; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_gioihanhosobenhnhan BEFORE INSERT ON public.benh_nhan FOR EACH ROW EXECUTE FUNCTION public.trg_gioihanhosobenhnhan();


--
-- TOC entry 4917 (class 2620 OID 17241)
-- Name: lich_hen trg_kiemtratrunglich; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kiemtratrunglich BEFORE INSERT OR UPDATE ON public.lich_hen FOR EACH ROW EXECUTE FUNCTION public.trg_kiemtratrunglich();


--
-- TOC entry 4918 (class 2620 OID 17245)
-- Name: chi_tiet_vat_tu trg_trutonkhovattu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_trutonkhovattu AFTER INSERT ON public.chi_tiet_vat_tu FOR EACH ROW EXECUTE FUNCTION public.trg_trutonkhovattu();


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


-- Completed on 2026-05-17 16:08:27

--
-- PostgreSQL database dump complete
--

\unrestrict Y5D1Pqy2aeljrDpQ7V4HLUJSQY8ivEbv6Q0J4KH5CFOq2VkuQItLiSCICuS1835

