--
-- PostgreSQL database dump
--

\restrict lEO6aQOaS5fK1mfJvhfb5OqElrableDpoghxnMsdpot7BrP1ribbQS5K9QZ2nfM

-- Dumped from database version 17.9
-- Dumped by pg_dump version 17.9

-- Started on 2026-05-20 13:11:27

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
-- TOC entry 237 (class 1255 OID 25734)
-- Name: fn_doanhthungay(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_doanhthungay(p_ngay date) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_Tong DECIMAL;
BEGIN
    SELECT SUM(TongThanhToan) INTO v_Tong 
    FROM HOA_DON 
    WHERE NgayLap::DATE = p_ngay;
    
    RETURN COALESCE(v_Tong, 0);
END;
$$;


--
-- TOC entry 238 (class 1255 OID 25735)
-- Name: fn_kiemtranhanvienranh(character varying, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_kiemtranhanvienranh(p_manv character varying, p_batdau timestamp without time zone, p_ketthuc timestamp without time zone) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM LICH_HEN 
        WHERE MaNhanVien = p_manv 
        AND TrangThai != 'Đã hủy'
        AND (p_batdau, p_ketthuc) OVERLAPS (ThoiGianBatDau, ThoiGianKetThuc)
    ) THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$;


--
-- TOC entry 239 (class 1255 OID 25736)
-- Name: fn_mucdokhancap(numeric, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_mucdokhancap(p_nhietdo numeric, p_nhiptim integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_nhietdo > 39.0 OR p_nhiptim > 120 THEN
        RETURN 'KHẨN CẤP - ƯU TIÊN 1';
    ELSIF p_nhietdo > 37.5 OR p_nhiptim > 100 THEN
        RETURN 'THEO DÕI - ƯU TIÊN 2';
    ELSE
        RETURN 'BÌNH THƯỜNG';
    END IF;
END;
$$;


--
-- TOC entry 235 (class 1255 OID 25732)
-- Name: fn_phanloainhomtuoi(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_phanloainhomtuoi(p_ngaysinh date) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_Tuoi INTEGER;
BEGIN
    v_Tuoi := EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_ngaysinh));
    
    IF v_Tuoi < 1 THEN RETURN 'Trẻ sơ sinh';
    ELSIF v_Tuoi < 16 THEN RETURN 'Trẻ em';
    ELSIF v_Tuoi < 60 THEN RETURN 'Người trưởng thành';
    ELSE RETURN 'Người cao tuổi';
    END IF;
END;
$$;


--
-- TOC entry 236 (class 1255 OID 25733)
-- Name: fn_tinhgiasauthue(numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_tinhgiasauthue(p_sotien numeric, p_thuesuat numeric DEFAULT 0.08) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN p_sotien * (1 + p_thuesuat);
END;
$$;


--
-- TOC entry 233 (class 1255 OID 25727)
-- Name: fn_tinhthoigiankham(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_tinhthoigiankham(p_batdau timestamp without time zone, p_ketthuc timestamp without time zone) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_Phut INTEGER;
BEGIN
    v_Phut := EXTRACT(EPOCH FROM (p_ketthuc - p_batdau)) / 60;
    RETURN v_Phut || ' phút';
END;
$$;


--
-- TOC entry 234 (class 1255 OID 25731)
-- Name: fn_tinhtuoi(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_tinhtuoi(p_ngaysinh date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_ngaysinh));
END;
$$;


--
-- TOC entry 252 (class 1255 OID 25738)
-- Name: sp_hoanthanhlichkham(character varying, text, character varying, integer, numeric); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_hoanthanhlichkham(IN p_malichhen character varying, IN p_chandoan text, IN p_huyetap character varying, IN p_nhiptim integer, IN p_nhietdo numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Cập nhật trạng thái lịch hẹn
    UPDATE public.lich_hen 
    SET TrangThai = 'Hoàn thành', ThoiGianKetThuc = CURRENT_TIMESTAMP
    WHERE MaLichHen = p_malichhen;

    -- Ghi nhận kết quả khám bệnh
    INSERT INTO public.ket_qua_kham (MaKetQua, MaLichHen, ChanDoanSoBo, HuyetAp, NhipTim, NhietDo)
    VALUES (REPLACE(p_malichhen, 'LH', 'KQ'), p_malichhen, p_chandoan, p_huyetap, p_nhiptim, p_nhietdo);

    -- Tự động gọi thủ tục tạo hóa đơn
    CALL public.sp_taohoadonthanhtoan(p_malichhen);
END;
$$;


--
-- TOC entry 251 (class 1255 OID 25737)
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
    -- Đã fix: thoigianbatdau viết liền
    SELECT CASE WHEN EXTRACT(HOUR FROM ThoiGianBatDau) >= 22 THEN 1.2 ELSE 1.0 END
    INTO v_heso FROM public.lich_hen WHERE MaLichHen = p_malichhen;

    -- Tính tiền dịch vụ
    SELECT COALESCE(dv.DonGiaTieuChuan * v_heso, 0) INTO v_tongtiendichvu
    FROM public.dich_vu dv JOIN public.lich_hen lh ON dv.MaDichVu = lh.MaDichVu
    WHERE lh.MaLichHen = p_malichhen;

    -- Tính tiền vật tư
    SELECT COALESCE(SUM(ct.SoLuong * ct.DonGiaThoiDiem), 0) INTO v_tongtienvattu
    FROM public.chi_tiet_vat_tu ct JOIN public.ket_qua_kham kq ON ct.MaKetQua = kq.MaKetQua
    WHERE kq.MaLichHen = p_malichhen;

    -- Tạo mã hóa đơn format HDKQUXxxx từ mã lịch hẹn
    v_mahoadon := 'HD' || REPLACE(p_malichhen, 'LH', 'KQ');

    -- Thêm dữ liệu vào bảng hóa đơn (bỏ cột sinh tự động)
    INSERT INTO public.hoa_don (MaHoaDon, MaLichHen, TongTienDichVu, TongTienVatTu, PhiPhatSinh, NgayLap)
    VALUES (v_mahoadon, p_malichhen, v_tongtiendichvu, v_tongtienvattu, 0, CURRENT_TIMESTAMP);
END;
$$;


--
-- TOC entry 262 (class 1255 OID 26221)
-- Name: sp_tudong_kichhoat_ca_kham(); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_tudong_kichhoat_ca_kham()
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. TỰ ĐỘNG CẬP NHẬT LỊCH HẸN KHI ĐẾN GIỜ (Kích hoạt trigger đổi luôn trạng thái NVYT sang Đang bận)
    UPDATE public.lich_hen
    SET trangthai = 'Đang thực hiện'
    WHERE trangthai = 'Đã phân công'
      AND CURRENT_TIMESTAMP >= thoigianbatdau;

    -- 2. TỰ ĐỘNG GIẢI PHÓNG NHÂN VIÊN KHI HẾT GIỜ KHÁM DỰ KIẾN (Nếu có điền thoigianketthuc)
    UPDATE public.nhan_vien_y_te
    SET trangthai = 'Sẵn sàng'
    WHERE manhanvien IN (
        SELECT manhanvien 
        FROM public.lich_hen 
        WHERE trangthai = 'Đang thực hiện' 
          AND thoigianketthuc IS NOT NULL 
          AND CURRENT_TIMESTAMP > thoigianketthuc
    );
END;
$$;


--
-- TOC entry 258 (class 1255 OID 25746)
-- Name: trg_ai_phantichcamxuc(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_ai_phantichcamxuc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.SoSao >= 4 
       OR NEW.NoiDung ILIKE ANY (ARRAY['%Tuyệt vời%', '%Rất hài lòng%', '%sạch sẽ%', '%hiện đại%', '%Dịch vụ tốt%', '%tận tâm%', '%Hài lòng%']) 
    THEN
        NEW.ai_phantichcamxuc := 'Tích cực';
    ELSIF NEW.SoSao <= 2 
       OR NEW.NoiDung ILIKE ANY (ARRAY['%Không hài lòng%', '%chưa tốt%', '%thất vọng%', '%quá tệ%', '%không quay lại%']) 
    THEN
        NEW.ai_phantichcamxuc := 'Tiêu cực';
    ELSE
        NEW.ai_phantichcamxuc := 'Trung tính';
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 259 (class 1255 OID 25747)
-- Name: trg_ai_phantichsuckhoe(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_ai_phantichsuckhoe() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (NEW.NhipTim > 100 AND NEW.NhietDo > 38.5) THEN
        NEW.ai_canhbaoruiro := 'CẢNH BÁO AI: Nguy cơ nhiễm trùng huyết hoặc suy tim cấp. Cần theo dõi đặc biệt.';
        NEW.ai_dotincay := 0.92;
    ELSIF (NEW.NhietDo > 39.0) THEN
        NEW.ai_canhbaoruiro := 'CẢNH BÁO AI: Nguy cơ sốt co giật.';
        NEW.ai_dotincay := 0.85;
    ELSE
        NEW.ai_canhbaoruiro := 'AI: Chỉ số trong ngưỡng an toàn.';
        NEW.ai_dotincay := 0.95;
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 253 (class 1255 OID 25739)
-- Name: trg_canhcaonhanvienhuylich(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_canhcaonhanvienhuylich() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_ThoiGianConLai INTERVAL;
BEGIN
    IF NEW.TrangThai = 'Đã hủy' AND OLD.TrangThai != 'Đã hủy' THEN
        v_ThoiGianConLai := NEW.ThoiGianBatDau - CURRENT_TIMESTAMP;

        IF v_ThoiGianConLai < INTERVAL '2 hours' THEN
            UPDATE NHAN_VIEN_Y_TE
            SET DiemUyTin = DiemUyTin - 0.5
            WHERE MaNhanVien = NEW.MaNhanVien;
            
            RAISE NOTICE 'Nhân viên bị trừ điểm uy tín do hủy lịch sát giờ (dưới 2 tiếng).';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 263 (class 1255 OID 26222)
-- Name: trg_chautrunglich_nhanvien(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_chautrunglich_nhanvien() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Chỉ kiểm tra khi ca hẹn có gán nhân viên y tế
    IF NEW.MaNhanVien IS NOT NULL THEN
        -- Kiểm tra xem có lịch hẹn nào khác của nhân viên này bị đè giờ không
        -- Ca trùng là ca chưa bị hủy/chưa hoàn thành và có thời gian giao thoa trong vòng 1 tiếng
        IF EXISTS (
            SELECT 1 FROM public.LICH_HEN
            WHERE MaNhanVien = NEW.MaNhanVien
              AND MaLichHen != NEW.MaLichHen -- Bỏ qua chính nó khi UPDATE
              AND TrangThai NOT IN ('Hoàn thành', 'Đã hủy')
              -- Logic chặn giao thoa thời gian (Giả định mỗi ca cách nhau tối thiểu 60 phút)
              AND NEW.ThoiGianBatDau >= ThoiGianBatDau - INTERVAL '59 minutes'
              AND NEW.ThoiGianBatDau <= ThoiGianBatDau + INTERVAL '59 minutes'
        ) THEN
            -- Bắn lỗi chặn đứng hành động INSERT/UPDATE lại ngay lập tức
            RAISE EXCEPTION 'Lỗi trùng lịch: Nhân viên % đã có lịch hẹn khác trong khung giờ này!', NEW.MaNhanVien;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- TOC entry 256 (class 1255 OID 25744)
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
-- TOC entry 254 (class 1255 OID 25740)
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
-- TOC entry 261 (class 1255 OID 25741)
-- Name: trg_kiemtrahosinhkhoasan(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_kiemtrahosinhkhoasan() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_LoaiNhanSu VARCHAR(50);
    v_TenChuyenKhoa VARCHAR(100);
BEGIN
    SELECT LoaiNhanSu INTO v_LoaiNhanSu FROM public.NHAN_VIEN_Y_TE WHERE MaNhanVien = NEW.MaNhanVien;
    SELECT TenChuyenKhoa INTO v_TenChuyenKhoa FROM public.CHUYEN_KHOA WHERE MaChuyenKhoa = NEW.MaChuyenKhoa;

    -- Đổi từ LIKE sang ILIKE để chấp nhận cả 'sản', 'Sản', 'SẢN'
    IF v_LoaiNhanSu = 'Hộ sinh' AND v_TenChuyenKhoa NOT ILIKE '%sản%' THEN
        RAISE EXCEPTION 'Lỗi: Nhân viên Hộ sinh chỉ được thuộc chuyên khoa Phụ sản!';
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 260 (class 1255 OID 25742)
-- Name: trg_kiemtraluongtrangthai(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_kiemtraluongtrangthai() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. Chặn sửa ca đã đóng
    IF TG_OP = 'UPDATE' AND OLD.TrangThai IN ('Hoàn thành', 'Đã hủy') THEN
        RAISE EXCEPTION 'Lỗi quy trình: Lịch hẹn đã hoàn thành hoặc đã hủy không thể chỉnh sửa!';
    END IF;

    -- 2. Xử lý khi trạng thái chủ động chuyển sang Đã hủy
    IF NEW.TrangThai = 'Đã hủy' THEN
        IF NEW.MaNhanVien IS NOT NULL THEN
            UPDATE public.NHAN_VIEN_Y_TE SET TrangThai = 'Sẵn sàng' WHERE MaNhanVien = NEW.MaNhanVien;
        END IF;
        RETURN NEW;
    END IF;

    -- 3. ÉP TRẠNG THÁI DỰA TRÊN THỜI GIAN VÀ NHÂN SỰ
    IF NEW.MaNhanVien IS NULL THEN
        IF CURRENT_TIMESTAMP > NEW.ThoiGianBatDau THEN
            NEW.TrangThai := 'Đã hủy';
        ELSE
            NEW.TrangThai := 'Chờ';
        END IF;
    ELSE
        -- Nếu giữ nguyên Hoàn thành từ SP hoanthanhlichkham
        IF NEW.TrangThai = 'Hoàn thành' THEN
            NULL;
        -- Nếu có người nhận + chưa tới giờ
        ELSIF CURRENT_TIMESTAMP < NEW.ThoiGianBatDau THEN
            NEW.TrangThai := 'Đã phân công';
        -- Nếu có người nhận + ĐÃ ĐẾN GIỜ HOẶC QUÁ GIỜ hoặc được SP quét chủ động chuyển sang 'Đang thực hiện'
        ELSIF CURRENT_TIMESTAMP >= NEW.ThoiGianBatDau OR NEW.TrangThai = 'Đang thực hiện' THEN
            NEW.TrangThai := 'Đang thực hiện';
        END IF;
    END IF;

    -- 4. ĐỒNG BỘ TRẠNG THÁI CHO NHÂN VIÊN Y TẾ (Sửa để ăn chặt với SP quét)
    IF NEW.TrangThai = 'Đang thực hiện' AND NEW.MaNhanVien IS NOT NULL THEN
        UPDATE public.NHAN_VIEN_Y_TE SET TrangThai = 'Đang bận' WHERE MaNhanVien = NEW.MaNhanVien;
    ELSIF NEW.TrangThai IN ('Đã phân công', 'Hoàn thành') AND NEW.MaNhanVien IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.lich_hen 
            WHERE MaNhanVien = NEW.MaNhanVien 
            AND MaLichHen != NEW.MaLichHen 
            AND TrangThai = 'Đang thực hiện'
        ) THEN
            UPDATE public.NHAN_VIEN_Y_TE SET TrangThai = 'Sẵn sàng' WHERE MaNhanVien = NEW.MaNhanVien;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 255 (class 1255 OID 25743)
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
-- TOC entry 257 (class 1255 OID 25745)
-- Name: trg_trutonkhovattu(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_trutonkhovattu() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE VAT_TU_Y_TE 
    SET SoLuongTon = SoLuongTon - NEW.SoLuong
    WHERE MaVatTu = NEW.MaVatTu;

    IF (SELECT SoLuongTon FROM VAT_TU_Y_TE WHERE MaVatTu = NEW.MaVatTu) < 0 THEN
        RAISE EXCEPTION 'Số lượng vật tư trong kho không đủ!';
    END IF;
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 221 (class 1259 OID 25571)
-- Name: admin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin (
    maadmin character varying(20) NOT NULL,
    mauser character varying(20) NOT NULL,
    hoten character varying(100),
    capdo character varying(50) DEFAULT 'Staff'::character varying,
    ngaytao timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- TOC entry 219 (class 1259 OID 25532)
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
    CONSTRAINT chk_bn_gioitinh CHECK (((gioitinh)::text = ANY ((ARRAY['Nam'::character varying, 'Nữ'::character varying, 'Khác'::character varying])::text[]))),
    CONSTRAINT chk_bn_ngaysinh CHECK ((ngaysinh <= CURRENT_DATE))
);


--
-- TOC entry 227 (class 1259 OID 25662)
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
-- TOC entry 222 (class 1259 OID 25585)
-- Name: chuyen_khoa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chuyen_khoa (
    machuyenkhoa character varying(20) NOT NULL,
    tenchuyenkhoa character varying(100) NOT NULL
);


--
-- TOC entry 229 (class 1259 OID 25698)
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
-- TOC entry 224 (class 1259 OID 25605)
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
-- TOC entry 228 (class 1259 OID 25679)
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
-- TOC entry 225 (class 1259 OID 25638)
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
-- TOC entry 218 (class 1259 OID 25517)
-- Name: khach_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.khach_hang (
    makhachhang character varying(20) NOT NULL,
    mauser character varying(20) NOT NULL,
    hoten character varying(100) NOT NULL,
    sodienthoai character varying(15) NOT NULL,
    diachi character varying(255),
    ngaytao timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- TOC entry 232 (class 1259 OID 26050)
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
-- TOC entry 217 (class 1259 OID 25505)
-- Name: nguoi_dung; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nguoi_dung (
    mauser character varying(20) NOT NULL,
    email character varying(100) NOT NULL,
    matkhau character varying(255) NOT NULL,
    loaiuser character varying(50) NOT NULL,
    trangthaitaikhoan character varying(50) DEFAULT 'Hoạt động'::character varying,
    ngaytao timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ngaycapnhat timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_user_loai CHECK (((loaiuser)::text = ANY ((ARRAY['KhachHang'::character varying, 'NhanVienYTe'::character varying, 'Admin'::character varying])::text[]))),
    CONSTRAINT chk_user_trangthai CHECK (((trangthaitaikhoan)::text = ANY ((ARRAY['Hoạt động'::character varying, 'Khóa'::character varying, 'Tạm khóa'::character varying])::text[])))
);


--
-- TOC entry 223 (class 1259 OID 25590)
-- Name: nhan_vien_chuyen_khoa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nhan_vien_chuyen_khoa (
    manhanvien character varying(20) NOT NULL,
    machuyenkhoa character varying(20) NOT NULL
);


--
-- TOC entry 220 (class 1259 OID 25546)
-- Name: nhan_vien_y_te; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nhan_vien_y_te (
    manhanvien character varying(20) NOT NULL,
    mauser character varying(20) NOT NULL,
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
-- TOC entry 226 (class 1259 OID 25654)
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
-- TOC entry 230 (class 1259 OID 25762)
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
-- TOC entry 231 (class 1259 OID 25776)
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
-- TOC entry 4882 (class 2606 OID 25579)
-- Name: admin admin_mauser_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin
    ADD CONSTRAINT admin_mauser_key UNIQUE (mauser);


--
-- TOC entry 4884 (class 2606 OID 25577)
-- Name: admin admin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin
    ADD CONSTRAINT admin_pkey PRIMARY KEY (maadmin);


--
-- TOC entry 4872 (class 2606 OID 25540)
-- Name: benh_nhan benh_nhan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.benh_nhan
    ADD CONSTRAINT benh_nhan_pkey PRIMARY KEY (mabenhnhan);


--
-- TOC entry 4898 (class 2606 OID 25668)
-- Name: chi_tiet_vat_tu chi_tiet_vat_tu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_vat_tu
    ADD CONSTRAINT chi_tiet_vat_tu_pkey PRIMARY KEY (maketqua, mavattu);


--
-- TOC entry 4886 (class 2606 OID 25589)
-- Name: chuyen_khoa chuyen_khoa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chuyen_khoa
    ADD CONSTRAINT chuyen_khoa_pkey PRIMARY KEY (machuyenkhoa);


--
-- TOC entry 4904 (class 2606 OID 25709)
-- Name: danh_gia danh_gia_malichhen_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danh_gia
    ADD CONSTRAINT danh_gia_malichhen_key UNIQUE (malichhen);


--
-- TOC entry 4906 (class 2606 OID 25707)
-- Name: danh_gia danh_gia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danh_gia
    ADD CONSTRAINT danh_gia_pkey PRIMARY KEY (madanhgia);


--
-- TOC entry 4890 (class 2606 OID 25614)
-- Name: dich_vu dich_vu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dich_vu
    ADD CONSTRAINT dich_vu_pkey PRIMARY KEY (madichvu);


--
-- TOC entry 4900 (class 2606 OID 25692)
-- Name: hoa_don hoa_don_malichhen_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_malichhen_key UNIQUE (malichhen);


--
-- TOC entry 4902 (class 2606 OID 25690)
-- Name: hoa_don hoa_don_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_pkey PRIMARY KEY (mahoadon);


--
-- TOC entry 4892 (class 2606 OID 25648)
-- Name: ket_qua_kham ket_qua_kham_malichhen_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ket_qua_kham
    ADD CONSTRAINT ket_qua_kham_malichhen_key UNIQUE (malichhen);


--
-- TOC entry 4894 (class 2606 OID 25646)
-- Name: ket_qua_kham ket_qua_kham_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ket_qua_kham
    ADD CONSTRAINT ket_qua_kham_pkey PRIMARY KEY (maketqua);


--
-- TOC entry 4866 (class 2606 OID 25524)
-- Name: khach_hang khach_hang_mauser_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_mauser_key UNIQUE (mauser);


--
-- TOC entry 4868 (class 2606 OID 25522)
-- Name: khach_hang khach_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_pkey PRIMARY KEY (makhachhang);


--
-- TOC entry 4870 (class 2606 OID 25526)
-- Name: khach_hang khach_hang_sodienthoai_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_sodienthoai_key UNIQUE (sodienthoai);


--
-- TOC entry 4908 (class 2606 OID 26057)
-- Name: lich_hen lich_hen_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_hen
    ADD CONSTRAINT lich_hen_pkey PRIMARY KEY (malichhen);


--
-- TOC entry 4862 (class 2606 OID 25516)
-- Name: nguoi_dung nguoi_dung_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nguoi_dung
    ADD CONSTRAINT nguoi_dung_email_key UNIQUE (email);


--
-- TOC entry 4864 (class 2606 OID 25514)
-- Name: nguoi_dung nguoi_dung_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nguoi_dung
    ADD CONSTRAINT nguoi_dung_pkey PRIMARY KEY (mauser);


--
-- TOC entry 4888 (class 2606 OID 25594)
-- Name: nhan_vien_chuyen_khoa nhan_vien_chuyen_khoa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_chuyen_khoa
    ADD CONSTRAINT nhan_vien_chuyen_khoa_pkey PRIMARY KEY (manhanvien, machuyenkhoa);


--
-- TOC entry 4874 (class 2606 OID 25563)
-- Name: nhan_vien_y_te nhan_vien_y_te_cccd_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_y_te
    ADD CONSTRAINT nhan_vien_y_te_cccd_key UNIQUE (cccd);


--
-- TOC entry 4876 (class 2606 OID 25561)
-- Name: nhan_vien_y_te nhan_vien_y_te_mauser_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_y_te
    ADD CONSTRAINT nhan_vien_y_te_mauser_key UNIQUE (mauser);


--
-- TOC entry 4878 (class 2606 OID 25559)
-- Name: nhan_vien_y_te nhan_vien_y_te_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_y_te
    ADD CONSTRAINT nhan_vien_y_te_pkey PRIMARY KEY (manhanvien);


--
-- TOC entry 4880 (class 2606 OID 25565)
-- Name: nhan_vien_y_te nhan_vien_y_te_sodienthoai_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_y_te
    ADD CONSTRAINT nhan_vien_y_te_sodienthoai_key UNIQUE (sodienthoai);


--
-- TOC entry 4896 (class 2606 OID 25661)
-- Name: vat_tu_y_te vat_tu_y_te_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_tu_y_te
    ADD CONSTRAINT vat_tu_y_te_pkey PRIMARY KEY (mavattu);


--
-- TOC entry 4925 (class 2620 OID 25756)
-- Name: danh_gia trigger_ai_phantichcamxuc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_ai_phantichcamxuc BEFORE INSERT OR UPDATE ON public.danh_gia FOR EACH ROW EXECUTE FUNCTION public.trg_ai_phantichcamxuc();


--
-- TOC entry 4922 (class 2620 OID 25752)
-- Name: ket_qua_kham trigger_ai_phantichsuckhoe; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_ai_phantichsuckhoe BEFORE INSERT OR UPDATE ON public.ket_qua_kham FOR EACH ROW EXECUTE FUNCTION public.trg_ai_phantichsuckhoe();


--
-- TOC entry 4926 (class 2620 OID 26223)
-- Name: lich_hen trigger_chan_trung_lich; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_chan_trung_lich BEFORE INSERT OR UPDATE ON public.lich_hen FOR EACH ROW EXECUTE FUNCTION public.trg_chautrunglich_nhanvien();


--
-- TOC entry 4920 (class 2620 OID 25754)
-- Name: benh_nhan trigger_gioihanhosobenhnhan; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_gioihanhosobenhnhan BEFORE INSERT ON public.benh_nhan FOR EACH ROW EXECUTE FUNCTION public.trg_gioihanhosobenhnhan();


--
-- TOC entry 4923 (class 2620 OID 25751)
-- Name: ket_qua_kham trigger_khoaketquakham; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_khoaketquakham BEFORE DELETE OR UPDATE ON public.ket_qua_kham FOR EACH ROW EXECUTE FUNCTION public.trg_khoaketquakham();


--
-- TOC entry 4921 (class 2620 OID 25753)
-- Name: nhan_vien_chuyen_khoa trigger_kiemtrahosinhkhoasan; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_kiemtrahosinhkhoasan BEFORE INSERT OR UPDATE ON public.nhan_vien_chuyen_khoa FOR EACH ROW EXECUTE FUNCTION public.trg_kiemtrahosinhkhoasan();


--
-- TOC entry 4927 (class 2620 OID 26219)
-- Name: lich_hen trigger_lich_hen_logic; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_lich_hen_logic BEFORE INSERT OR UPDATE ON public.lich_hen FOR EACH ROW EXECUTE FUNCTION public.trg_kiemtraluongtrangthai();


--
-- TOC entry 4924 (class 2620 OID 25755)
-- Name: chi_tiet_vat_tu trigger_trutonkhovattu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_trutonkhovattu BEFORE INSERT ON public.chi_tiet_vat_tu FOR EACH ROW EXECUTE FUNCTION public.trg_trutonkhovattu();


--
-- TOC entry 4915 (class 2606 OID 25669)
-- Name: chi_tiet_vat_tu chi_tiet_vat_tu_maketqua_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_vat_tu
    ADD CONSTRAINT chi_tiet_vat_tu_maketqua_fkey FOREIGN KEY (maketqua) REFERENCES public.ket_qua_kham(maketqua) ON DELETE CASCADE;


--
-- TOC entry 4916 (class 2606 OID 25674)
-- Name: chi_tiet_vat_tu chi_tiet_vat_tu_mavattu_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_vat_tu
    ADD CONSTRAINT chi_tiet_vat_tu_mavattu_fkey FOREIGN KEY (mavattu) REFERENCES public.vat_tu_y_te(mavattu);


--
-- TOC entry 4912 (class 2606 OID 25580)
-- Name: admin fk_admin_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin
    ADD CONSTRAINT fk_admin_user FOREIGN KEY (mauser) REFERENCES public.nguoi_dung(mauser) ON DELETE CASCADE;


--
-- TOC entry 4910 (class 2606 OID 25541)
-- Name: benh_nhan fk_bn_khachhang; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.benh_nhan
    ADD CONSTRAINT fk_bn_khachhang FOREIGN KEY (makhachhang) REFERENCES public.khach_hang(makhachhang) ON DELETE CASCADE;


--
-- TOC entry 4909 (class 2606 OID 25527)
-- Name: khach_hang fk_kh_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT fk_kh_user FOREIGN KEY (mauser) REFERENCES public.nguoi_dung(mauser) ON DELETE CASCADE;


--
-- TOC entry 4917 (class 2606 OID 26058)
-- Name: lich_hen fk_lh_benhnhan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_hen
    ADD CONSTRAINT fk_lh_benhnhan FOREIGN KEY (mabenhnhan) REFERENCES public.benh_nhan(mabenhnhan) ON DELETE RESTRICT;


--
-- TOC entry 4918 (class 2606 OID 26063)
-- Name: lich_hen fk_lh_dichvu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_hen
    ADD CONSTRAINT fk_lh_dichvu FOREIGN KEY (madichvu) REFERENCES public.dich_vu(madichvu);


--
-- TOC entry 4919 (class 2606 OID 26068)
-- Name: lich_hen fk_lh_nhanvien; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_hen
    ADD CONSTRAINT fk_lh_nhanvien FOREIGN KEY (manhanvien) REFERENCES public.nhan_vien_y_te(manhanvien);


--
-- TOC entry 4911 (class 2606 OID 25566)
-- Name: nhan_vien_y_te fk_nv_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_y_te
    ADD CONSTRAINT fk_nv_user FOREIGN KEY (mauser) REFERENCES public.nguoi_dung(mauser) ON DELETE CASCADE;


--
-- TOC entry 4913 (class 2606 OID 25600)
-- Name: nhan_vien_chuyen_khoa nhan_vien_chuyen_khoa_machuyenkhoa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_chuyen_khoa
    ADD CONSTRAINT nhan_vien_chuyen_khoa_machuyenkhoa_fkey FOREIGN KEY (machuyenkhoa) REFERENCES public.chuyen_khoa(machuyenkhoa) ON DELETE CASCADE;


--
-- TOC entry 4914 (class 2606 OID 25595)
-- Name: nhan_vien_chuyen_khoa nhan_vien_chuyen_khoa_manhanvien_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_chuyen_khoa
    ADD CONSTRAINT nhan_vien_chuyen_khoa_manhanvien_fkey FOREIGN KEY (manhanvien) REFERENCES public.nhan_vien_y_te(manhanvien) ON DELETE CASCADE;


-- Completed on 2026-05-20 13:11:28

--
-- PostgreSQL database dump complete
--

\unrestrict lEO6aQOaS5fK1mfJvhfb5OqElrableDpoghxnMsdpot7BrP1ribbQS5K9QZ2nfM

