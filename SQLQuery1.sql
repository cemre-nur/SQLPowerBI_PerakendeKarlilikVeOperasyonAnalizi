/* ====================================================================
   PROJE: Kurumsal Perakende Veri Ambarı (GlobalRetail_DWH)
   MİMARİ: Yıldız Şeması (Star Schema) - DDL Scriptleri
   ==================================================================== */

-- --------------------------------------------------------------------
-- ADIM 1: VERİTABANI OLUŞTURMA VE SEÇME
-- --------------------------------------------------------------------

-- CREATE DATABASE: Veritabanı oluştur demektir.
-- DWH: Data Warehouse (Veri Ambarı) kısaltmasıdır.
CREATE DATABASE GlobalRetail_DWH;
GO -- GO: T-SQL'de toplu işlem ayırıcıdır. "Bu komut tamamen bitmeden alt satıra geçme" der.

-- USE: Kullanılacak aktif veritabanını seçer.
-- Kodların sistem veritabanları (master vb.) yerine bu ambarın içine yazılmasını sağlar.
USE GlobalRetail_DWH;
GO


-- --------------------------------------------------------------------
-- ADIM 2: MÜŞTERİ BOYUT TABLOSU (DimCustomer)
-- Dim: Dimension (Boyut) kelimesinin kısaltmasıdır.
-- --------------------------------------------------------------------

-- CREATE TABLE: Yeni bir tablo oluştur komutudur.
CREATE TABLE DimCustomer (
    -- INT: Tam sayı (Integer).
    -- PRIMARY KEY: Birincil Anahtar. Değerin benzersiz (tekil) ve boş olamaz (NOT NULL) olduğunu garanti eder.
    CustomerID INT PRIMARY KEY,

    -- NVARCHAR(100): Metin tipi (Unicode destekli). 'N' harfi Türkçe karakterlerin bozulmasını önler. En fazla 100 karakter alır.
    -- NOT NULL: Bu alan boş geçilemez, mutlaka veri girilmelidir.
    CustomerName NVARCHAR(100) NOT NULL,

    -- Segment: Bireysel, Kurumsal gibi müşteri sınıfı.
    Segment NVARCHAR(50),

    -- City: Şehir bilgisi.
    City NVARCHAR(50),

    -- PostaCode: İlk etapta yanlış isimle açılan posta kodu alanı.
    PostaCode NVARCHAR(20)
);
GO

-- EXEC (EXECUTE): Saklı yordamı (Stored Procedure) çalıştır demektir.
-- sp_rename: SQL Server'ın nesne/sütun adı değiştirme sistem prosedürüdür.
-- 'COLUMN': SQL Server'a tablonun içindeki bir "sütunu" (kolonu) yeniden adlandırdığımızı bildirir.
EXEC sp_rename 'DimCustomer.PostaCode', 'PostalCode', 'COLUMN';
GO

-- ALTER TABLE: Var olan bir tablonun yapısını güncelle / değiştir komutudur.
-- ADD: Tabloya yeni bir sütun ekler (tabloyu silip baştan yapmaya gerek kalmaz).
ALTER TABLE DimCustomer
ADD State NVARCHAR(50); -- Eyalet / İl coğrafi alanı eklendi.
GO


-- --------------------------------------------------------------------
-- ADIM 3: ÜRÜN BOYUT TABLOSU (DimProduct)
-- --------------------------------------------------------------------

CREATE TABLE DimProduct (
    -- ProductID: Ürünün benzersiz kimlik numarası.
    ProductID INT PRIMARY KEY,

    -- ProductName: Ürün adı (en fazla 150 karakter, boş olamaz).
    ProductName NVARCHAR(150) NOT NULL,

    -- Category: Ana ürün grubu (örn: Teknoloji, Mobilya).
    Category NVARCHAR(50) NOT NULL,

    -- SubCategory: Alt ürün grubu (örn: Telefonlar, Sandalyeler).
    SubCategory NVARCHAR(50) NOT NULL,

    -- CostPrice: Ürünün üretim/tedarik maliyeti.
    -- DECIMAL(18, 2): Finansal veri tipi. Toplam 18 basamak, virgülden sonra tam 2 basamak (kuruş) hassasiyeti.
    CostPrice DECIMAL(18, 2) NOT NULL,

    -- UnitPrice: Standart liste satış fiyatı.
    UnitPrice DECIMAL(18, 2) NOT NULL
);
GO


-- --------------------------------------------------------------------
-- ADIM 4: MAĞAZA VE LOKASYON BOYUT TABLOSU (DimStore)
-- --------------------------------------------------------------------

CREATE TABLE DimStore (
    -- StoreID: Mağaza / şube kimlik numarası.
    StoreID INT PRIMARY KEY,

    -- StoreName: Şubenin adı (örn: Kadıköy AVM, Aliağa Şube).
    StoreName NVARCHAR(100) NOT NULL,

    -- StoreType: Şube tipi (Flagship, Express, E-Ticaret Depo).
    StoreType NVARCHAR(50),

    -- StoreSizeSquareMeters: Mağaza metrekaresi (Metrekare başı satış analizi için tam sayı).
    StoreSizeSquareMeters INT,

    -- RegionManager: Bölgeden sorumlu şube müdürü.
    RegionManager NVARCHAR(100),

    -- Region & Country: Bölge ve Ülke tanımları.
    Region NVARCHAR(50),
    Country NVARCHAR(50)
);
GO


-- --------------------------------------------------------------------
-- ADIM 5: SATIŞ HAREKETLERİ OLGU TABLOSU (FactSales)
-- Fact: Eylemleri, hareketleri ve sayısal ölçümleri tutan merkez tablo.
-- --------------------------------------------------------------------

CREATE TABLE FactSales (
    -- BIGINT: Çok büyük tam sayı. Perakendede milyarlarca işlem olabileceği için seçildi.
    SalesID BIGINT PRIMARY KEY,

    -- DATE: Yıl-Ay-Gün formatında tarih (Saat/dakika gereksiz disk kaplamasın diye).
    OrderDate DATE NOT NULL, -- Sipariş verilme tarihi
    ShipDate DATE,           -- Kargoya verilme tarihi

    -- Boyut tablolarına bağlanacak yabancı anahtar sütunları (Kimlikler)
    CustomerID INT NOT NULL, -- Hangi müşteri satın aldı?
    ProductID INT NOT NULL,  -- Hangi ürün satıldı?
    StoreID INT NOT NULL,    -- Hangi mağazadan satıldı?

    -- İşlem metrikleri
    Quantity INT NOT NULL,               -- Satış adedi
    UnitPrice DECIMAL(18, 2) NOT NULL,   -- Satış anındaki birim fiyat

    -- Discount: İndirim/iskonto oranı (örn: %15 için 0.15).
    -- DECIMAL(4, 2): Toplam 4 hane, 2'si virgülden sonra.
    -- DEFAULT 0.00: İndirim girilmezse hücre NULL (boş) kalmasın, otomatik 0 olsun kuralı.
    Discount DECIMAL(4, 2) DEFAULT 0.00,

    -- ShippingCost: Kargo maliyeti tutarı.
    -- DEFAULT 0.00: Kargo masrafı girilmezse boş kalmasın, otomatik 0 olsun.
    ShippingCost DECIMAL(18, 2) DEFAULT 0.00,

    -- ----------------------------------------------------------------
    -- İLİŞKİ VE GÜVENLİK KURALLARI (Foreign Keys - Yabancı Anahtarlar)
    -- ----------------------------------------------------------------
    -- CONSTRAINT: SQL'e güvenlik kısıtı/kuralı tanımlıyorum demektir.
    -- FOREIGN KEY: Bu sütunun bağımsız olmadığını, başka tablodan geldiğini belirtir.
    -- REFERENCES: Hangi tablo ve sütuna baktığını gösterir (Olmayan müşteri/ürün girişini engeller).

    CONSTRAINT FK_FactSales_Customer FOREIGN KEY (CustomerID) REFERENCES DimCustomer(CustomerID),
    CONSTRAINT FK_FactSales_Product  FOREIGN KEY (ProductID)  REFERENCES DimProduct(ProductID),
    CONSTRAINT FK_FactSales_Store    FOREIGN KEY (StoreID)    REFERENCES DimStore(StoreID)
);
GO

/* ====================================================================
   DML (Data Manipulation Language) - VERİ EKLEME
   TABLO: DimCustomer (Müşteri Boyutu)
   ==================================================================== */

-- INSERT INTO: Tabloya yeni satırlar ekleyeceğimizi belirtir.
-- Parantez içinde hangi sütunlara veri göndereceğimizi sırayla yazarız.
INSERT INTO DimCustomer (CustomerID,CustomerName,Segment,City,State, PostalCode)
VALUES
    -- Sayısal ID tırnaksız, metinler tek tırnak içinde ('...')
    (101, N'Ahmet Yılmaz', N'Bireysel', N'İstanbul', N'Marmara', N'34000'),
    (102, N'Ayşe Demir', N'Kurumsal', N'Ankara', N'İç Anadolu', N'06000'),
    (103, N'Mehmet Kaya', N'Küçük İşletme', N'İzmir', N'Ege', N'35000'),
    (104, N'Fatma Çelik', N'Bireysel', N'Bursa', N'Marmara', N'16000'),
    (105, N'Ali Öztürk', N'Kurumsal', N'Antalya', N'Akdeniz', N'07000'),
    (106, N'Zeynep Aydın', N'Bireysel', N'İzmir', N'Ege', N'35100'),
    (107, N'Caner Yıldız', N'Kurumsal', N'Kocaeli', N'Marmara', N'41000'),
    (108, N'Elif Şahin', N'Küçük İşletme', N'Eskişehir', N'İç Anadolu', N'26000'),
    (109, N'Burak Doğan', N'Bireysel', N'Adana', N'Akdeniz', N'01000'),
    (110, N'Selin Koç', N'Kurumsal', N'İstanbul', N'Marmara', N'34100'),
    (111, N'Emre Arslan', N'Küçük İşletme', N'Gaziantep', N'Güneydoğu Anadolu', N'27000'),
    (112, N'Derya Güneş', N'Bireysel', N'Samsun', N'Karadeniz', N'55000'),
    (113, N'Mert Polat', N'Bireysel', N'Trabzon', N'Karadeniz', N'61000'),
    (114, N'Gözde Kurt', N'Kurumsal', N'Konya', N'İç Anadolu', N'42000'),
    (115, N'Hakan Bulut', N'Küçük İşletme', N'Manisa', N'Ege', N'45000'),
    (116, N'Tolga Çetin', N'Bireysel', N'Mersin', N'Akdeniz', N'33000'),
    (117, N'Büşra Yaman', N'Kurumsal', N'Kayseri', N'İç Anadolu', N'38000'),
    (118, N'Onur Keskin', N'Küçük İşletme', N'Denizli', N'Ege', N'20000'),
    (119, N'Ezgi Aksoy', N'Bireysel', N'Diyarbakır', N'Güneydoğu Anadolu', N'21000'),
    (120, N'Serkan Erdem', N'Kurumsal', N'Tekirdağ', N'Marmara', N'59000'),
    (121, N'İrem Vural', N'Bireysel', N'Balıkesir', N'Marmara', N'10000'),
    (122, N'Murat Özcan', N'Küçük İşletme', N'Çanakkale', N'Marmara', N'17000'),
    (123, N'Pınar Taşkın', N'Kurumsal', N'Aydın', N'Ege', N'09000'),
    (124, N'Kemal Bozkurt', N'Bireysel', N'Muğla', N'Ege', N'48000'),
    (125, N'Ceren Yıldırım', N'Küçük İşletme', N'Sakarya', N'Marmara', N'54000'),
    (126, N'Barış Tunç', N'Kurumsal', N'Hatay', N'Akdeniz', N'31000'),
    (127, N'Duygu Şimşek', N'Bireysel', N'Malatya', N'Doğu Anadolu', N'44000'),
    (128, N'Okan Karaca', N'Küçük İşletme', N'Erzurum', N'Doğu Anadolu', N'25000'),
    (129, N'Sinem Yavuz', N'Kurumsal', N'Sivas', N'İç Anadolu', N'58000'),
    (130, N'Kaan Gül', N'Bireysel', N'Afyonkarahisar', N'Ege', N'03000');
GO



/* ====================================================================
   DML (Data Manipulation Language) - VERİ EKLEME
   TABLO: DimProduct (Ürün Boyutu - Katalog Verileri)
   ==================================================================== */

-- INSERT INTO: DimProduct tablosuna ürün kayıtlarını ekler.
-- Sütun sırası: ProductID, ProductName, Category, SubCategory, CostPrice, UnitPrice
INSERT INTO DimProduct (ProductID, ProductName, Category, SubCategory, CostPrice, UnitPrice)
VALUES
    -- TEKNOLOJİ KATEGORİSİ
    (201, N'UltraBook Pro 15', N'Technology', N'Laptops', 18500.00, 24999.00),
    (202, N'Gaming Masaüstü PC', N'Technology', N'Computers', 26000.00, 34500.00),
    (203, N'Kablosuz Gürültü Engelleyici Kulaklık', N'Technology', N'Audio', 1200.00, 2199.00),
    (204, N'Akıllı Telefon 128GB', N'Technology', N'Phones', 14000.00, 19500.00),
    (205, N'27 inç 4K Monitör', N'Technology', N'Accessories', 4500.00, 6800.00),
    (206, N'Mekanik Oyuncu Klavyesi', N'Technology', N'Accessories', 850.00, 1450.00),
    (207, N'Ergonomik Kablosuz Mouse', N'Technology', N'Accessories', 350.00, 650.00),
    (208, N'Bluetooth Konferans Hoparlörü', N'Technology', N'Audio', 1650.00, 2800.00),
    (209, N'Taşınabilir SSD 1TB', N'Technology', N'Storage', 1900.00, 3100.00),
    (210, N'Kablosuz Şarj Standı', N'Technology', N'Accessories', 420.00, 790.00),

    -- MOBİLYA KATEGORİSİ
    (211, N'Ergonomik Yönetici Koltuğu', N'Furniture', N'Chairs', 3200.00, 4850.00),
    (212, N'Yüksekliği Ayarlanabilir Çalışma Masası', N'Furniture', N'Tables', 5100.00, 7900.00),
    (213, N'5 Raflı Metal Kitaplık', N'Furniture', N'Bookcases', 1100.00, 1850.00),
    (214, N'Ahşap Toplantı Masası', N'Furniture', N'Tables', 8500.00, 12500.00),
    (215, N'Akustik Ofis Bölme Paneli', N'Furniture', N'Furnishings', 950.00, 1600.00),
    (216, N'L Köşe Çalışma İstasyonu', N'Furniture', N'Tables', 6200.00, 9400.00),
    (217, N'Ayarlanabilir Monitör Kolu', N'Furniture', N'Furnishings', 750.00, 1350.00),
    (218, N'Ofis İçi Çöp ve Geri Dönüşüm Ünitesi', N'Furniture', N'Furnishings', 600.00, 1100.00),
    (219, N'Misafir Bekleme Koltuğu (İkili)', N'Furniture', N'Chairs', 2800.00, 4400.00),
    (220, N'Mobil Keson Dolap (Kilitli)', N'Furniture', N'Storage', 1350.00, 2250.00),

    -- OFİS MALZEMELERİ KATEGORİSİ
    (221, N'A4 Fotokopi Kağıdı (5 Koli)', N'Office Supplies', N'Paper', 450.00, 750.00),
    (222, N'Evrak İmha Makinesi', N'Office Supplies', N'Appliances', 1800.00, 2900.00),
    (223, N'Metal Çekmeceli Evrak Dolabı', N'Office Supplies', N'Storage', 2100.00, 3300.00),
    (224, N'Laminasyon Makinesi', N'Office Supplies', N'Appliances', 650.00, 1150.00),
    (225, N'Geniş Kapasiteli Klasör (10 Adet)', N'Office Supplies', N'Binders', 120.00, 240.00),
    (226, N'Lazer Sunum Kalemi & Kumanda', N'Office Supplies', N'Accessories', 280.00, 520.00),
    (227, N'Tükenmez Kalem Seti (50 Adet)', N'Office Supplies', N'Art', 95.00, 190.00),
    (228, N'Manyetik Beyaz Yazı Tahtası 90x120', N'Office Supplies', N'Furnishings', 550.00, 950.00),
    (229, N'Ağır Hizmet Tipi Tel Zımba Makinesi', N'Office Supplies', N'Appliances', 320.00, 580.00),
    (230, N'Masaüstü Evrak Rafı (3 Katlı)', N'Office Supplies', N'Storage', 180.00, 340.00);



/* ====================================================================
   DML (Data Manipulation Language) - VERİ EKLEME
   TABLO: DimStore (Mağaza ve Lokasyon Boyutu)
   ==================================================================== */

-- Varsa önceki deneme kayıtlarını temizle
TRUNCATE TABLE DimStore;

-- INSERT INTO: Mağaza ve dağıtım merkezlerini ekler.
-- Sütun sırası: StoreID, StoreName, StoreType, StoreSizeSquareMeters, RegionManager, Region, Country
INSERT INTO DimStore (StoreID, StoreName, StoreType, StoreSizeSquareMeters, RegionManager, Region, Country)
VALUES
    (1, N'Kadıköy Flagship', N'Flagship', 2200, N'Ahmet Eren', N'Marmara', N'Türkiye'),
    (2, N'Levent Plaza Şube', N'Supermarket', 850, N'Ahmet Eren', N'Marmara', N'Türkiye'),
    (3, N'Kızılay Merkez Şube', N'Flagship', 1800, N'Sevgi Yılmaz', N'İç Anadolu', N'Türkiye'),
    (4, N'Tunalı Hilmi Express', N'Express', 320, N'Sevgi Yılmaz', N'İç Anadolu', N'Türkiye'),
    (5, N'Alsancak Bulvar', N'Flagship', 1600, N'Oğuz Karahan', N'Ege', N'Türkiye'),
    (6, N'Bornova Forum AVM', N'Supermarket', 900, N'Oğuz Karahan', N'Ege', N'Türkiye'),
    (7, N'Muratpaşa Sahil', N'Supermarket', 750, N'Kemal Can', N'Akdeniz', N'Türkiye'),
    (8, N'Nilüfer AVM Şube', N'Supermarket', 820, N'Ahmet Eren', N'Marmara', N'Türkiye'),
    (9, N'Atakum Express', N'Express', 280, N'Berrin Çetin', N'Karadeniz', N'Türkiye'),
    (10, N'E-Ticaret Ana Dağıtım Merkezi', N'Online Fulfillment', 5000, N'Hakan Vural', N'Marmara', N'Türkiye');



/* ====================================================================
   DML (Data Manipulation Language) - VERİ YÜKLEME
   TABLO: FactSales (Satış Hareketleri Olgu Tablosu - 60 Satır)
   ==================================================================== */

-- Sütun Sırası:
-- SalesID, OrderDate, ShipDate, CustomerID, ProductID, StoreID, Quantity, UnitPrice, Discount, ShippingCost

INSERT INTO FactSales (SalesID, OrderDate, ShipDate, CustomerID, ProductID, StoreID, Quantity, UnitPrice, Discount, ShippingCost)
VALUES
    -- OCAK 2026 HAREKETLERİ
    (1001, '2026-01-05', '2026-01-07', 101, 201, 1, 1, 24999.00, 0.05, 120.00),
    (1002, '2026-01-08', '2026-01-11', 102, 211, 3, 3, 4850.00, 0.00, 250.00),
    (1003, '2026-01-12', '2026-01-14', 103, 221, 10, 10, 750.00, 0.10, 85.00),
    (1004, '2026-01-15', '2026-01-16', 104, 204, 8, 1, 19500.00, 0.00, 0.00),
    (1005, '2026-01-20', '2026-01-23', 105, 205, 7, 2, 6800.00, 0.15, 140.00),
    (1006, '2026-01-20', '2026-01-23', 105, 208, 7, 1, 2800.00, 0.10, 45.00),
    (1007, '2026-01-22', '2026-01-25', 106, 207, 5, 2, 650.00, 0.00, 0.00),
    (1008, '2026-01-28', '2026-01-30', 107, 225, 2, 20, 240.00, 0.20, 110.00),

    -- ŞUBAT 2026 HAREKETLERİ
    (1009, '2026-02-02', '2026-02-05', 108, 212, 10, 2, 7900.00, 0.05, 320.00),
    (1010, '2026-02-06', '2026-02-08', 109, 203, 4, 1, 2199.00, 0.00, 0.00),
    (1011, '2026-02-10', '2026-02-12', 110, 202, 1, 1, 34500.00, 0.00, 0.00),
    (1012, '2026-02-14', '2026-02-16', 111, 222, 10, 2, 2900.00, 0.10, 150.00),
    (1013, '2026-02-18', '2026-02-21', 112, 209, 9, 3, 3100.00, 0.05, 60.00),
    (1014, '2026-02-22', '2026-02-24', 113, 227, 10, 15, 190.00, 0.00, 40.00),
    (1015, '2026-02-26', '2026-03-01', 114, 214, 3, 1, 12500.00, 0.10, 500.00),

    -- MART 2026 HAREKETLERİ
    (1016, '2026-03-02', '2026-03-04', 115, 206, 6, 2, 1450.00, 0.00, 0.00),
    (1017, '2026-03-06', '2026-03-09', 116, 223, 7, 2, 3300.00, 0.08, 190.00),
    (1018, '2026-03-10', '2026-03-12', 117, 216, 10, 4, 9400.00, 0.15, 450.00),
    (1019, '2026-03-15', '2026-03-18', 118, 210, 5, 3, 790.00, 0.00, 0.00),
    (1020, '2026-03-20', '2026-03-22', 119, 204, 10, 1, 19500.00, 0.05, 90.00),
    (1021, '2026-03-25', '2026-03-27', 120, 228, 2, 5, 950.00, 0.10, 120.00),

    -- NİSAN 2026 HAREKETLERİ
    (1022, '2026-04-03', '2026-04-05', 121, 201, 8, 1, 24999.00, 0.00, 0.00),
    (1023, '2026-04-07', '2026-04-10', 122, 213, 10, 3, 1850.00, 0.05, 140.00),
    (1024, '2026-04-12', '2026-04-14', 123, 218, 5, 4, 600.00, 0.00, 0.00),
    (1025, '2026-04-18', '2026-04-20', 124, 217, 6, 2, 1350.00, 0.00, 0.00),
    (1026, '2026-04-22', '2026-04-25', 125, 224, 10, 3, 1150.00, 0.10, 80.00),
    (1027, '2026-04-27', '2026-04-30', 126, 202, 7, 2, 34500.00, 0.05, 200.00),

    -- MAYIS 2026 HAREKETLERİ
    (1028, '2026-05-02', '2026-05-04', 127, 205, 10, 1, 6800.00, 0.00, 75.00),
    (1029, '2026-05-06', '2026-05-09', 128, 211, 10, 4, 4850.00, 0.12, 310.00),
    (1030, '2026-05-11', '2026-05-13', 129, 226, 3, 2, 520.00, 0.00, 0.00),
    (1031, '2026-05-15', '2026-05-18', 130, 219, 5, 2, 4400.00, 0.10, 180.00),
    (1032, '2026-05-20', '2026-05-22', 101, 209, 1, 1, 3100.00, 0.00, 0.00),
    (1033, '2026-05-25', '2026-05-27', 102, 220, 3, 3, 2250.00, 0.05, 150.00),
    (1034, '2026-05-28', '2026-05-30', 103, 229, 6, 4, 580.00, 0.00, 0.00),

    -- HAZİRAN 2026 HAREKETLERİ
    (1035, '2026-06-02', '2026-06-04', 104, 203, 8, 1, 2199.00, 0.00, 0.00),
    (1036, '2026-06-07', '2026-06-10', 105, 230, 7, 5, 340.00, 0.00, 50.00),
    (1037, '2026-06-12', '2026-06-15', 106, 201, 5, 1, 24999.00, 0.08, 0.00),
    (1038, '2026-06-16', '2026-06-18', 107, 215, 2, 2, 1600.00, 0.00, 0.00),
    (1039, '2026-06-21', '2026-06-24', 108, 221, 10, 15, 750.00, 0.15, 110.00),
    (1040, '2026-06-26', '2026-06-28', 109, 207, 4, 1, 650.00, 0.00, 0.00),

    -- TEMMUZ 2026 HAREKETLERİ
    (1041, '2026-07-03', '2026-07-05', 110, 205, 1, 3, 6800.00, 0.10, 0.00),
    (1042, '2026-07-08', '2026-07-11', 111, 212, 10, 1, 7900.00, 0.00, 220.00),
    (1043, '2026-07-13', '2026-07-15', 112, 204, 9, 1, 19500.00, 0.00, 0.00),
    (1044, '2026-07-18', '2026-07-21', 113, 225, 10, 8, 240.00, 0.00, 45.00),
    (1045, '2026-07-23', '2026-07-25', 114, 206, 3, 1, 1450.00, 0.00, 0.00),
    (1046, '2026-07-28', '2026-07-31', 115, 216, 6, 2, 9400.00, 0.10, 180.00),

    -- AĞUSTOS 2026 HAREKETLERİ
    (1047, '2026-08-02', '2026-08-04', 116, 208, 7, 2, 2800.00, 0.05, 0.00),
    (1048, '2026-08-06', '2026-08-09', 117, 222, 10, 3, 2900.00, 0.10, 160.00),
    (1049, '2026-08-11', '2026-08-14', 118, 214, 10, 1, 12500.00, 0.15, 550.00),
    (1050, '2026-08-16', '2026-08-18', 119, 202, 10, 1, 34500.00, 0.00, 150.00),
    (1051, '2026-08-21', '2026-08-23', 120, 227, 2, 10, 190.00, 0.00, 0.00),
    (1052, '2026-08-26', '2026-08-28', 121, 210, 8, 2, 790.00, 0.00, 0.00),

    -- EYLÜL 2026 HAREKETLERİ
    (1053, '2026-09-01', '2026-09-03', 122, 223, 10, 2, 3300.00, 0.05, 120.00),
    (1054, '2026-09-03', '2026-09-05', 123, 201, 5, 2, 24999.00, 0.10, 0.00),
    (1055, '2026-09-04', '2026-09-06', 124, 213, 6, 1, 1850.00, 0.00, 0.00),
    (1056, '2026-09-06', '2026-09-08', 125, 205, 10, 2, 6800.00, 0.05, 90.00),
    (1057, '2026-09-07', '2026-09-09', 126, 211, 7, 3, 4850.00, 0.08, 180.00),
    (1058, '2026-09-08', '2026-09-10', 127, 218, 10, 6, 600.00, 0.00, 60.00),
    (1059, '2026-09-09', '2026-09-11', 128, 204, 10, 2, 19500.00, 0.05, 110.00),
    (1060, '2026-09-10', '2026-09-11', 129, 209, 3, 2, 3100.00, 0.00, 0.00);


/* ====================================================================
   SQL VIEW: vw_SalesAnalytics
   AMAÇ: Tüm boyutları ve kilit finansal metrikleri birleştiren 
         raporlama katmanı sanal tablosu.
   ==================================================================== */

CREATE VIEW vw_SalesAnalytics AS 
SELECT 
    -- Satış ve Tarih Bilgileri
    f.SalesID,
    f.OrderDate,
    f.ShipDate,
    
    -- DATEDIFF: İki tarih arasındaki gün farkını hesaplar (Kargo teslim/hazırlık süresi)
    DATEDIFF(DAY, f.OrderDate, f.ShipDate) AS DeliveryDays,

    -- Müşteri Boyut Bilgileri
    c.CustomerID,
    c.CustomerName,
    c.Segment,
    c.City AS CustomerCity,
    c.State AS CustomerRegion,

    -- Ürün Boyut Bilgileri
    p.ProductID,
    p.ProductName,
    p.Category,
    p.SubCategory,
    p.CostPrice,

    -- Mağaza Boyut Bilgileri
    s.StoreID,
    s.StoreName,
    s.StoreType,
    s.StoreSizeSquareMeters,
    s.RegionManager,

    -- Temel Hareket Verileri
    f.Quantity,
    f.UnitPrice,
    f.Discount,
    f.ShippingCost,

    -- ----------------------------------------------------------------
    -- FİNANSAL METRİKLER (HESAPLANAN ALANLAR)
    -- ----------------------------------------------------------------
    
    -- Brüt Ciro: İndirimsiz toplam tutar
    (f.Quantity * f.UnitPrice) AS GrossRevenue,

    -- İndirim Tutarı: Uygulanan toplam TL indirim
    (f.Quantity * f.UnitPrice * f.Discount) AS DiscountAmount,

    -- Net Ciro: Kasaya fiilen giren para
    (f.Quantity * f.UnitPrice * (1 - f.Discount)) AS NetRevenue,

    -- Satılan Malın Toplam Maliyeti (COGS)
    (f.Quantity * p.CostPrice) AS TotalCost,

    -- Net Kâr: Net Cirodan ürün maliyeti ve kargo masrafı düşüldükten sonra kalan şirket kârı
    ((f.Quantity * f.UnitPrice * (1 - f.Discount)) - (f.Quantity * p.CostPrice) - f.ShippingCost) AS NetProfit

FROM FactSales f -- Takma Ad / Kısaltma
-- INNER JOIN: İki tabloyu ortak anahtarları üzerinden birleştirir
INNER JOIN DimCustomer c ON f.CustomerID = c.CustomerID
INNER JOIN DimProduct  p ON f.ProductID  = p.ProductID
INNER JOIN DimStore    s ON f.StoreID    = s.StoreID;
GO


select * from vw_SalesAnalytics