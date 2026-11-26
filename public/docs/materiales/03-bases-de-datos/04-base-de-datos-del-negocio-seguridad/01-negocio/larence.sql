-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 07-07-2026 a las 20:36:18
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `larence`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `aplicar_descuento_volumen` (IN `p_id_detalle` INT)   BEGIN
    UPDATE detalle_pedidos
    SET precio_unitario = precio_unitario * 0.90
    WHERE id_detalle_pedido = p_id_detalle
      AND cantidad > 50;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `calcular_total_con_iva` (IN `p_id_pedido` INT, OUT `p_total_final` DECIMAL(10,2))   BEGIN
    DECLARE v_subtotal DECIMAL(10,2);

    SELECT monto_total_pedido INTO v_subtotal
    FROM pedidos
    WHERE id_pedido = p_id_pedido;

    SET p_total_final = v_subtotal * 1.16;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `generar_reporte_ventas_dia` (IN `p_fecha` DATE)   BEGIN
    SELECT p.nombre_producto,
           SUM(dp.cantidad) AS total_vendido,
           SUM(dp.cantidad * dp.precio_unitario) AS monto_total
    FROM productos p
    JOIN detalle_pedidos dp ON p.id_producto = dp.id_producto
    JOIN pedidos ped ON dp.id_pedido = ped.id_pedido
    WHERE DATE(ped.fecha_pedido) = p_fecha
    GROUP BY p.nombre_producto;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `registrar_pedido_seguro` (IN `p_id_cliente` INT, IN `p_id_producto` INT, IN `p_cantidad` INT, IN `p_precio` DECIMAL(10,2), OUT `p_mensaje` VARCHAR(100))   BEGIN

    DECLARE v_stock_actual INT;

    

    -- Manejador de errores (Si algo falla, hace ROLLBACK)

    DECLARE EXIT HANDLER FOR SQLEXCEPTION

    BEGIN

        ROLLBACK;

        SET p_mensaje = 'Error en la transacci├│n. Cambios revertidos.';

    END;



    -- Iniciamos la transacci├│n

    START TRANSACTION;

    

    -- Bloqueamos la fila del producto para evitar lecturas fantasmas

    SELECT stock INTO v_stock_actual FROM larence.productos WHERE id_producto = p_id_producto FOR UPDATE;

    

    IF v_stock_actual >= p_cantidad THEN

        -- Descontamos el inventario

        UPDATE larence.productos SET stock = stock - p_cantidad WHERE id_producto = p_id_producto;

        

        -- Confirmamos los cambios

        COMMIT;

        SET p_mensaje = 'Pedido registrado y stock descontado con ├®xito.';

    ELSE

        ROLLBACK;

        SET p_mensaje = 'Transacci├│n rechazada: Stock insuficiente en almac├®n.';

    END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `verificar_reposicion` (IN `p_total_final` DECIMAL(10,2))   BEGIN

    SELECT nombre_producto, stock 

    FROM productos 

    WHERE stock < 10;

END$$

--
-- Funciones
--
CREATE DEFINER=`root`@`localhost` FUNCTION `calcular_precio_bs` (`p_precio_dolares` DECIMAL(10,2)) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN

    DECLARE v_tasa_actual DECIMAL(10,2);

    DECLARE v_precio_final DECIMAL(10,2);

    

    -- Buscar la tasa activa m├ís reciente

    SELECT monto_tasa INTO v_tasa_actual FROM larence.tasa_dia WHERE status = 1 ORDER BY id_tasa DESC LIMIT 1;

    

    -- Calcular

    SET v_precio_final = p_precio_dolares * v_tasa_actual;

    

    RETURN v_precio_final;

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categorias`
--

CREATE TABLE `categorias` (
  `id_categoria` int(11) NOT NULL,
  `nombre_categoria` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `categorias`
--

INSERT INTO `categorias` (`id_categoria`, `nombre_categoria`, `status`) VALUES
(1, 'Galletas Dulces', 1),
(2, 'Galletas Saladas', 1),
(3, 'Postres y Rellenas', 1),
(4, 'Reposteria', 1),
(5, 'Arequipe', 0),
(6, 'electrodomesticos x', 0),
(7, 'Bebidas x', 0);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clientes`
--

CREATE TABLE `clientes` (
  `id_cliente` int(11) NOT NULL,
  `tipo_id` varchar(11) NOT NULL,
  `id_tipo_cliente` int(11) DEFAULT NULL,
  `nombre_cliente` varchar(100) NOT NULL,
  `direccion_cliente` varchar(100) NOT NULL,
  `sector` varchar(50) NOT NULL,
  `tlf_cliente` varchar(11) NOT NULL,
  `email_cliente` varchar(100) NOT NULL,
  `estado_cliente` varchar(100) NOT NULL,
  `img_cliente` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `clientes`
--

INSERT INTO `clientes` (`id_cliente`, `tipo_id`, `id_tipo_cliente`, `nombre_cliente`, `direccion_cliente`, `sector`, `tlf_cliente`, `email_cliente`, `estado_cliente`, `img_cliente`, `status`) VALUES
(1234567, 'J', 2, 'Elite bien', 'Av Lara carrera 6', 'Este', '04162372439', 'elite@gmail.com', 'Activo', 'assets/img/clientes/elite.png', 1),
(17100998, 'J', 2, 'Farmatodo', 'Av Pedro leon con calle 54', 'Oeste', '02511358621', 'farmatodo@gmail.com', 'Activo', 'assets/img/clientes/farmatodo.png', 1),
(25566580, 'V', 1, 'Juan Perez', 'Urb Eligio Macias Mujica Calle 3 Urb Eligio Macias Mujica Calle 3', 'Sur', '04122373562', 'yijofo1151@hotkev.com', 'Activo', 'assets/img/clientes/descarga.jpg', 1),
(25566582, 'V', 1, 'Miguel Bose', 'Urb Eligio Macias Mujica Calle 3 Urb Eligio Macias Mujica Calle 3', 'Sur', '04122373562', 'eliasarmas0902@gmail.com', 'Activo', 'assets/img/clientes/marlon perez.jpg', 1),
(25566585, 'V', 1, 'Jesus andrade', 'Urb Eligio Macias Mujica Calle 3 Urb Eligio Macias Mujica Calle 3', 'Sur', '04122373562', 'eliasarmas0902@gmail.com', 'Pendiente', 'assets/img/clientes/descarga.jpg', 1),
(31039811, 'J', 4, 'PaTodo', 'Av Urb Patarata con Calle 20', 'Centro', '02513213495', 'patodo@gmail.com', 'Activo', 'assets/img/clientes/patodo.jpg', 1),
(32200771, 'J', 3, 'Mi Super ca', 'Cale 54 con Carrera 20', 'Oeste', '02514408820', 'misuper@gmail.com', 'Activo', 'assets/img/clientes/miSuper.png', 1),
(33220448, 'V', 5, 'Gabriela Hernandez', 'la rotaria', 'Oeste', '04245064176', 'mariagabrielahm08@gmail.com', 'Anulado', 'assets/img/clientes/WIN_20260329_18_31_33_Pro.jpg', 1),
(33220449, 'V', 1, '@superusuario_24', 'Sistema', 'Norte', '04120000000', 'moises2005pereira@gmail.com', 'Activo', '', 1),
(322034534, 'J', 2, 'William', 'Cale 54 con Carrera 20', 'Norte', '02514408820', 'misuper@gmail.com', 'Activo', 'assets/img/clientes/andres castellanos.jpg', 1),
(363653676, 'J', 3, 'super moi', 'calle 22 carrera 1', 'Norte', '02514408820', 'misuper@gmail.com', 'Activo', 'assets/img/clientes/oscar yanes.jpg', 1);

--
-- Disparadores `clientes`
--
DELIMITER $$
CREATE TRIGGER `trg_bloquear_eliminar_cliente` BEFORE DELETE ON `clientes` FOR EACH ROW BEGIN IF (SELECT COUNT(*) FROM larence.pedidos WHERE id_cliente = OLD.id_cliente) > 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar: Cliente tiene pedidos.'; END IF; END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `compras`
--

CREATE TABLE `compras` (
  `id_compra` int(11) NOT NULL,
  `id_proveedor` int(11) NOT NULL,
  `fecha_compra` datetime(6) NOT NULL,
  `monto_total_compra` float(11,2) NOT NULL,
  `id_tasa` int(11) NOT NULL,
  `id_estado_pago` int(11) NOT NULL,
  `observaciones` varchar(300) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `compras`
--

INSERT INTO `compras` (`id_compra`, `id_proveedor`, `fecha_compra`, `monto_total_compra`, `id_tasa`, `id_estado_pago`, `observaciones`, `status`) VALUES
(1, 12321234, '2026-06-05 00:00:00.000000', 150.00, 1, 2, 'Abastecimiento de Harina (Pagada)', 1),
(2, 31039711, '2026-06-10 00:00:00.000000', 60.00, 1, 2, 'Abastecimiento de Az??car (Pendiente)', 1),
(3, 12321234, '2026-06-16 00:00:00.000000', 650.00, 1, 1, 'ssghsftghdffgshfgh', 1),
(4, 12321234, '2026-06-17 00:00:00.000000', 50.00, 2, 2, 'hgdhjdhj', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cuenta_x_cobrar`
--

CREATE TABLE `cuenta_x_cobrar` (
  `id_cuenta_x_cobrar` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL,
  `monto_total` float(11,2) NOT NULL,
  `saldo_pendiente` float(11,2) NOT NULL,
  `fecha_emision` date NOT NULL,
  `fecha_vencimiento` date NOT NULL,
  `estado_cuenta` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `cuenta_x_cobrar`
--

INSERT INTO `cuenta_x_cobrar` (`id_cuenta_x_cobrar`, `id_pedido`, `id_cliente`, `monto_total`, `saldo_pendiente`, `fecha_emision`, `fecha_vencimiento`, `estado_cuenta`, `status`) VALUES
(1, 1, 1234567, 525.00, 0.00, '2026-06-09', '2026-06-24', 'Pagado', 1),
(2, 2, 32200771, 400.00, 400.00, '2026-06-10', '2026-06-25', 'Por Pagar', 1),
(3, 4, 1234567, 353.50, 353.50, '2026-06-12', '2026-06-27', 'Por Pagar', 1),
(4, 4, 1234567, 300.00, 300.00, '2026-06-12', '2026-06-27', 'Por Pagar', 1),
(5, 5, 17100998, 150.00, 150.00, '2026-06-12', '2026-06-27', 'Por Pagar', 1),
(6, 6, 31039811, 100.00, 0.00, '2026-06-12', '2026-06-27', 'Pagado', 1),
(7, 7, 32200771, 250.00, 250.00, '2026-06-12', '2026-06-15', 'Por Pagar', 1),
(8, 8, 33220448, 50.00, 0.00, '2026-06-12', '2026-06-27', 'Pagado', 1),
(9, 10, 1234567, 352.50, 350.00, '2026-06-12', '2026-06-27', 'Por Pagar', 1),
(10, 11, 1234567, 150.00, 150.00, '2026-06-12', '2026-06-27', 'Por Pagar', 1),
(14, 14, 17100998, 450.00, 450.00, '2026-06-12', '2026-06-27', 'Por Pagar', 1),
(15, 15, 1234567, 975.00, 975.00, '2026-06-12', '2026-06-27', 'Por Pagar', 1),
(16, 16, 17100998, 352.50, 352.50, '2026-06-12', '2026-06-27', 'Por Pagar', 1),
(17, 17, 25566580, 250.00, 0.00, '2026-06-12', '2026-06-19', 'Pagado', 1),
(18, 18, 1234567, 350.00, 0.00, '2026-06-16', '2026-07-01', 'Pagado', 1),
(19, 21, 25566580, 350.00, 0.00, '2026-06-16', '2026-06-23', 'Pagado', 1),
(20, 22, 25566582, 163.50, 160.00, '2026-06-17', '2026-06-24', 'Por Pagar', 1),
(21, 23, 25566580, 150.00, 150.00, '2026-06-17', '2026-06-24', 'Por Pagar', 1),
(22, 24, 1234567, 150.00, 150.00, '2026-06-26', '2026-07-11', 'Por Pagar', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cuenta_x_pagar`
--

CREATE TABLE `cuenta_x_pagar` (
  `id_cuenta_x_pagar` int(11) NOT NULL,
  `id_compra` int(11) NOT NULL,
  `id_proveedor` int(11) NOT NULL,
  `monto_total` float(11,2) NOT NULL,
  `saldo_pendiente` float(11,2) NOT NULL,
  `fecha_emision` datetime(6) NOT NULL,
  `fecha_vencimiento` datetime(6) NOT NULL,
  `estado_pago` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `cuenta_x_pagar`
--

INSERT INTO `cuenta_x_pagar` (`id_cuenta_x_pagar`, `id_compra`, `id_proveedor`, `monto_total`, `saldo_pendiente`, `fecha_emision`, `fecha_vencimiento`, `estado_pago`, `status`) VALUES
(1, 1, 12321234, 150.00, 0.00, '2026-06-05 00:00:00.000000', '2026-06-20 00:00:00.000000', 'Pagado', 1),
(2, 2, 31039711, 60.00, 0.00, '2026-06-10 00:00:00.000000', '2026-06-25 00:00:00.000000', 'Pagado', 1),
(3, 3, 12321234, 650.00, 650.00, '2026-06-16 00:00:00.000000', '2026-07-16 00:00:00.000000', 'Por Pagar', 1),
(4, 4, 12321234, 50.00, 0.00, '2026-06-17 00:00:00.000000', '2026-07-17 00:00:00.000000', 'Pagado', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalles_entregas`
--

CREATE TABLE `detalles_entregas` (
  `id_detalle_entrega` int(11) NOT NULL,
  `id_entrega` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL,
  `tlt_contacto` varchar(11) NOT NULL,
  `direccion_entrega` varchar(100) NOT NULL,
  `cantidad_caja` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `detalles_entregas`
--

INSERT INTO `detalles_entregas` (`id_detalle_entrega`, `id_entrega`, `id_pedido`, `id_cliente`, `tlt_contacto`, `direccion_entrega`, `cantidad_caja`) VALUES
(1, 1, 1, 1234567, '04162372439', 'Av Lara carrera 6', 150),
(2, 2, 2, 32200771, '02514408820', 'Cale 54 con Carrera 20', 200),
(3, 3, 3, 17100998, '02511358621', 'Av Pedro leon con calle 54', 50),
(4, 4, 10, 1234567, '0412-237356', 'Avenida La Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto, Parroquia Juan de Villegas', 101),
(5, 5, 16, 17100998, '0412-237356', 'Avenida la Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto, Parroquia Juan de Villegas', 201),
(6, 6, 15, 1234567, '0412-237356', 'Avenida La Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto, Parroquia Juan de Villegas', 290),
(7, 7, 5, 1234567, '04162372439', 'Av Lara carrera 6', 75),
(8, 7, 4, 1234567, '0412-237356', 'Aeropostal, Avenida la Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto', 186),
(9, 8, 11, 1234567, '0412-237356', 'Aeropostal, Avenida la Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto', 100),
(10, 9, 14, 17100998, '0412-237356', 'Avenida la Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto, Parroquia Juan de Villegas', 200);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_compras`
--

CREATE TABLE `detalle_compras` (
  `id_detalle_compra` int(11) NOT NULL,
  `id_compra` int(11) NOT NULL,
  `id_materia_prima` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_unitario` float(11,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `detalle_compras`
--

INSERT INTO `detalle_compras` (`id_detalle_compra`, `id_compra`, `id_materia_prima`, `cantidad`, `precio_unitario`) VALUES
(1, 1, 1, 10, 15.00),
(2, 2, 3, 5, 12.00),
(3, 3, 1, 100, 5.00),
(4, 3, 4, 50, 3.00),
(5, 4, 1, 10, 5.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_pedidos`
--

CREATE TABLE `detalle_pedidos` (
  `id_detalle_pedido` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_unitario` float(11,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `detalle_pedidos`
--

INSERT INTO `detalle_pedidos` (`id_detalle_pedido`, `id_pedido`, `id_producto`, `cantidad`, `precio_unitario`) VALUES
(1, 1, 2, 150, 3.15),
(2, 2, 3, 200, 2.00),
(3, 3, 1, 50, 1.50),
(4, 4, 2, 101, 353.50),
(5, 10, 2, 100, 350.00),
(6, 10, 4, 1, 2.50),
(7, 11, 1, 100, 150.00),
(8, 4, 2, 85, 3.50),
(9, 5, 3, 75, 2.00),
(10, 6, 1, 66, 1.50),
(11, 7, 4, 100, 2.50),
(12, 8, 2, 14, 3.50),
(13, 12, 3, 25, 2.00),
(16, 14, 2, 50, 175.00),
(17, 14, 4, 50, 125.00),
(18, 14, 1, 100, 150.00),
(19, 15, 2, 250, 875.00),
(20, 15, 4, 40, 100.00),
(21, 16, 2, 200, 350.00),
(22, 16, 4, 1, 2.50),
(23, 17, 4, 100, 250.00),
(24, 18, 2, 100, 350.00),
(25, 21, 2, 100, 350.00),
(26, 22, 1, 109, 163.50),
(27, 23, 1, 100, 150.00),
(28, 24, 1, 100, 150.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_producciones`
--

CREATE TABLE `detalle_producciones` (
  `id_detalle_produccion` int(11) NOT NULL,
  `id_produccion` int(11) NOT NULL,
  `id_materia_prima` int(11) NOT NULL,
  `cantidad_utilizada` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `detalle_producciones`
--

INSERT INTO `detalle_producciones` (`id_detalle_produccion`, `id_produccion`, `id_materia_prima`, `cantidad_utilizada`) VALUES
(1, 3, 1, 10),
(2, 3, 1, 5),
(3, 3, 3, 5),
(4, 4, 1, 5),
(5, 4, 2, 5),
(6, 4, 4, 5),
(7, 5, 1, 10),
(8, 6, 1, 10);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_promocion`
--

CREATE TABLE `detalle_promocion` (
  `id_detalle_promocion` int(11) NOT NULL,
  `id_promocion` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `detalle_promocion`
--

INSERT INTO `detalle_promocion` (`id_detalle_promocion`, `id_promocion`, `id_producto`) VALUES
(1, 1, 1),
(2, 1, 4),
(7, 2, 1),
(8, 3, 1),
(9, 4, 1),
(10, 5, 2);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entregas`
--

CREATE TABLE `entregas` (
  `id_entregas` int(11) NOT NULL,
  `fecha_entrega_programada` date NOT NULL,
  `fecha_entrega_real` date DEFAULT NULL,
  `id_estado_entrega` int(11) NOT NULL,
  `repartidor` varchar(200) NOT NULL,
  `observaciones` varchar(300) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `id_pedido` int(11) NOT NULL,
  `id_estado` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `entregas`
--

INSERT INTO `entregas` (`id_entregas`, `fecha_entrega_programada`, `fecha_entrega_real`, `id_estado_entrega`, `repartidor`, `observaciones`, `status`, `id_pedido`, `id_estado`) VALUES
(1, '2026-06-10', '2026-06-10', 1, 'Moises Pereira', 'Entrega sin problemas', 1, 1, 0),
(2, '2026-06-11', NULL, 2, 'Ismael Torres', 'En camino al oeste', 1, 2, 0),
(3, '2026-06-12', '2026-06-11', 3, 'Santiago Loyo', 'Cancelada: Local comercial cerrado por protesta en la zona', 1, 3, 0),
(4, '2026-06-19', NULL, 2, 'carlos', 'ghggh', 1, 10, 0),
(5, '2026-06-15', NULL, 2, 'carlos', 'fdfdf', 1, 15, 0),
(6, '2026-06-20', NULL, 2, 'moises', 'jfjd', 1, 16, 0),
(7, '2026-06-23', '2026-06-17', 1, 'moises', 'dhgjdyjdhgj', 1, 0, 0),
(8, '2026-06-16', '2026-06-16', 1, 'moises', 'sgbsfgbsgfbsfb', 1, 0, 0),
(9, '2026-06-24', NULL, 2, 'carlos', '', 1, 0, 0);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entrega_pedidos`
--

CREATE TABLE `entrega_pedidos` (
  `id_entrega_pedido` int(11) NOT NULL,
  `id_entrega` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL,
  `direccion_entrega` varchar(300) NOT NULL,
  `tlf_contacto` varchar(12) DEFAULT NULL,
  `cantidad_cajas` int(11) NOT NULL DEFAULT 0,
  `observaciones` varchar(300) DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `entrega_pedidos`
--

INSERT INTO `entrega_pedidos` (`id_entrega_pedido`, `id_entrega`, `id_pedido`, `id_cliente`, `direccion_entrega`, `tlf_contacto`, `cantidad_cajas`, `observaciones`, `status`) VALUES
(1, 9, 14, 17100998, 'Avenida la Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto, Parroquia Juan de Villegas', '0412-237356', 200, '', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estado_entrega`
--

CREATE TABLE `estado_entrega` (
  `id_estado_entrega` int(11) NOT NULL,
  `nombre_estado` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `estado_entrega`
--

INSERT INTO `estado_entrega` (`id_estado_entrega`, `nombre_estado`) VALUES
(1, 'Entregado'),
(2, 'En ruta'),
(3, 'Cancelado');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estado_pago`
--

CREATE TABLE `estado_pago` (
  `id_estado_pago` int(11) NOT NULL,
  `nombre_estado` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `estado_pago`
--

INSERT INTO `estado_pago` (`id_estado_pago`, `nombre_estado`) VALUES
(1, 'Por Pagar'),
(2, 'Pagado');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estado_pedido`
--

CREATE TABLE `estado_pedido` (
  `id_estado_pedido` int(11) NOT NULL,
  `nombre_estado` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `estado_pedido`
--

INSERT INTO `estado_pedido` (`id_estado_pedido`, `nombre_estado`) VALUES
(1, 'Pendiente'),
(2, 'Procesando'),
(3, 'Por Enviar'),
(4, 'Por Pagar'),
(5, 'Entregado'),
(6, 'Pagado');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `materia_prima`
--

CREATE TABLE `materia_prima` (
  `id_materia_prima` int(11) NOT NULL,
  `nombre_materia_prima` varchar(100) NOT NULL,
  `descripcion_materia_prima` varchar(100) NOT NULL,
  `id_unidad_medida` int(11) NOT NULL,
  `stock_actual` int(11) NOT NULL,
  `id_proveedor` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `materia_prima`
--

INSERT INTO `materia_prima` (`id_materia_prima`, `nombre_materia_prima`, `descripcion_materia_prima`, `id_unidad_medida`, `stock_actual`, `id_proveedor`, `status`) VALUES
(1, 'Harina de Trigo', 'Harina para elaboracion de galletas', 1, 140, 12321234, 1),
(2, 'Huevos', 'Elaboracion de galletas a base de huevo', 5, 40, 17100998, 1),
(3, 'Azucar Nevada', 'Para la dulzura de galletas', 1, 5, 31039711, 1),
(4, 'Margarina', 'Materia grasa para postress', 3, 70, 12321234, 1),
(5, 'Harina Leudante', 'Para cocinar', 5, 20, 17100998, 0),
(6, 'Levadura triple', 'Elaboracion de galletas a base de levadura', 2, 90, 17100998, 0),
(7, 'Esencia triple', 'para sabor y aroma', 2, 90, 478475938, 0);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `metodos_pago`
--

CREATE TABLE `metodos_pago` (
  `id_metodo_pago` int(11) NOT NULL,
  `nombre_metodo` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `metodos_pago`
--

INSERT INTO `metodos_pago` (`id_metodo_pago`, `nombre_metodo`) VALUES
(1, 'Transferencia'),
(2, 'Pago Movil'),
(3, 'Efectivo');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pagos`
--

CREATE TABLE `pagos` (
  `id_pago` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `monto_pago` float(11,2) NOT NULL,
  `fecha_pago` datetime(6) NOT NULL,
  `nro_referencia` varchar(11) NOT NULL,
  `concepto` varchar(200) NOT NULL,
  `id_metodo_pago` int(11) NOT NULL,
  `img_pago` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `pagos`
--

INSERT INTO `pagos` (`id_pago`, `id_pedido`, `monto_pago`, `fecha_pago`, `nro_referencia`, `concepto`, `id_metodo_pago`, `img_pago`) VALUES
(1, 1, 525.00, '2026-06-09 14:00:00.000000', '12345678901', 'Pago completo', 1, 'assets/img/pagos/voucher1.jpg'),
(2, 17, 250.00, '2026-06-12 00:00:00.000000', '87658758765', 'hgckhc', 1, 'assets/img/pagos/pucca.jpg'),
(3, 8, 50.00, '2026-06-16 00:00:00.000000', '35635435655', 'dgdghdghjh', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(4, 6, 100.00, '2026-06-16 00:00:00.000000', '35635635635', 'hgdhgdgjdj', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(5, 18, 350.00, '2026-06-16 00:00:00.000000', '47846784678', 'gsgdgndn', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(6, 21, 350.00, '2026-06-16 00:00:00.000000', '25625246564', 'xgsgfghfgh', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(7, 10, 2.50, '2026-06-17 00:00:00.000000', '24562525645', 'dsghghh', 1, 'assets/img/pagos/fondo_atardecer.jpg'),
(8, 22, 3.50, '0000-00-00 00:00:00.000000', '34563456354', 'pago', 1, 'assets/img/pagos/fondo_paisaje.jpg');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pagos_proveedores`
--

CREATE TABLE `pagos_proveedores` (
  `id_pago_proveedor` int(11) NOT NULL,
  `id_cuenta_x_pagar` int(11) NOT NULL,
  `monto` float(11,2) NOT NULL,
  `fecha_pago` float NOT NULL,
  `id_metodo_pago` int(11) NOT NULL,
  `nro_referencia` text NOT NULL,
  `concepto` varchar(300) NOT NULL,
  `img_pago` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `pagos_proveedores`
--

INSERT INTO `pagos_proveedores` (`id_pago_proveedor`, `id_cuenta_x_pagar`, `monto`, `fecha_pago`, `id_metodo_pago`, `nro_referencia`, `concepto`, `img_pago`) VALUES
(1, 2, 60.00, 2026, 1, '36736573673', 'hshghfghssghsg', 'assets/img/pagos/fondo_paisaje.jpg'),
(2, 4, 50.00, 2026, 1, '25545453454', 'cvbvsdfs', 'assets/img/pagos/fondo_atardecer.jpg');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedidos`
--

CREATE TABLE `pedidos` (
  `id_pedido` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL,
  `fecha_pedido` datetime(6) NOT NULL,
  `id_estado_pedido` int(11) NOT NULL,
  `id_estado_pago` int(11) NOT NULL,
  `monto_total_pedido` float(11,2) NOT NULL,
  `direccion_entrega` varchar(200) NOT NULL,
  `tlf_contacto` varchar(11) NOT NULL,
  `observaciones` varchar(250) NOT NULL,
  `id_promocion` int(11) DEFAULT NULL,
  `id_tasa` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `pedidos`
--

INSERT INTO `pedidos` (`id_pedido`, `id_cliente`, `fecha_pedido`, `id_estado_pedido`, `id_estado_pago`, `monto_total_pedido`, `direccion_entrega`, `tlf_contacto`, `observaciones`, `id_promocion`, `id_tasa`, `status`) VALUES
(1, 1234567, '2026-06-09 00:00:00.000000', 5, 2, 525.00, 'Av Lara carrera 6', '0416-237243', 'Entregar en almac?®n principal', NULL, 1, 1),
(2, 32200771, '2026-06-10 00:00:00.000000', 2, 1, 400.00, 'Cale 54 con Carrera 20', '0251-440882', 'Llamar al llegar', NULL, 1, 1),
(3, 17100998, '2026-06-11 00:00:00.000000', 1, 1, 75.00, 'Av Pedro leon con calle 54', '0251-135862', 'Pedido cancelado por el cliente', NULL, 1, 1),
(4, 1234567, '2026-06-12 00:00:00.000000', 5, 1, 353.50, 'Aeropostal, Avenida la Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto', '0412-237356', 'hey', NULL, 1, 1),
(5, 1234567, '2026-06-12 10:00:00.000000', 5, 1, 300.00, 'Av Lara carrera 6', '04162372439', 'Pedido de prueba 300', NULL, 1, 1),
(6, 17100998, '2026-06-12 10:30:00.000000', 1, 2, 150.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido de prueba 150', NULL, 1, 1),
(7, 31039811, '2026-06-12 11:00:00.000000', 1, 1, 100.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido de prueba 100', NULL, 1, 1),
(8, 32200771, '2026-06-12 11:30:00.000000', 5, 2, 250.00, 'Cale 54 con Carrera 20', '02514408820', 'Pedido de prueba 250', NULL, 1, 1),
(10, 1234567, '2026-06-12 00:00:00.000000', 5, 1, 352.50, 'Avenida La Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto, Parroquia Juan de Villegas', '0412-237356', 'hey', NULL, 1, 1),
(11, 1234567, '2026-06-12 00:00:00.000000', 1, 1, 150.00, 'Aeropostal, Avenida la Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto', '0412-237356', 'hey', NULL, 1, 1),
(12, 33220448, '2026-06-12 00:00:00.000000', 1, 1, 50.00, 'la rotaria', '04245064176', 'Pedido de prueba 50', NULL, 1, 1),
(14, 17100998, '2026-06-12 00:00:00.000000', 5, 1, 450.00, 'Avenida la Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto, Parroquia Juan de Villegas', '0412-237356', 'hey', NULL, 1, 1),
(15, 1234567, '2026-06-12 00:00:00.000000', 5, 1, 975.00, 'Avenida La Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto, Parroquia Juan de Villegas', '0412-237356', 'dffddf', NULL, 1, 1),
(16, 17100998, '2026-06-12 00:00:00.000000', 5, 1, 352.50, 'Avenida la Salle, Urbanizaci??n Andr?®s Eloy Blanco, Barquisimeto, Parroquia Juan de Villegas', '0412-237356', 'gdg', 2, 1, 1),
(17, 25566580, '2026-06-12 00:00:00.000000', 1, 2, 250.00, 'Urb Eligio Macias Mujica Calle 3 Urb Eligio Macias Mujica Calle 3', '04122373562', 'mbvcmbcbv', NULL, 1, 1),
(18, 1234567, '2026-06-16 00:00:00.000000', 1, 2, 350.00, 'Calle 3, San Francisco, Zona Industrial III, Barquisimeto', '0251-440882', 'sdgsdfgsf', NULL, 1, 1),
(21, 25566580, '2026-06-16 00:00:00.000000', 1, 2, 350.00, 'Calle 2, San Francisco, Urbanización Andrés Eloy Blanco, Barquisimeto', '02514408820', 'ourybfpquiyfbsr', NULL, 1, 1),
(22, 25566582, '2026-06-17 00:00:00.000000', 1, 1, 163.50, 'Calle 1, Zona Industrial II, Barquisimeto, Parroquia Unión', '04163213495', 'rfsdfbsdfb', NULL, 2, 1),
(23, 25566580, '2026-06-17 00:00:00.000000', 1, 1, 150.00, 'Calle 2, Zona Industrial III, Barquisimeto, Parroquia Juan de Villegas', '02514408820', 'tgegtsgbgb', NULL, 2, 1),
(24, 1234567, '2026-06-26 00:00:00.000000', 1, 1, 150.00, 'Urb Eligio Macias Mujica Calle 3 Urb Eligio Macias Mujica Calle 3', '04122373562', 'hola', NULL, 4, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `producciones`
--

CREATE TABLE `producciones` (
  `id_produccion` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `cantidad_producida` int(11) NOT NULL,
  `fecha_produccion` date NOT NULL,
  `motivo_produccion` varchar(100) NOT NULL,
  `observacion` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `producciones`
--

INSERT INTO `producciones` (`id_produccion`, `id_producto`, `cantidad_producida`, `fecha_produccion`, `motivo_produccion`, `observacion`, `status`) VALUES
(3, 1, 1, '2026-06-16', 'para stock', 'produccion de pueba a cargo del supervisor nuevo', 1),
(4, 1, 10, '2026-06-16', 'para stock', 'produccion de pueba a cargo del supervisor nuevo', 1),
(5, 1, 498, '2026-06-16', 'para stock', 'produccion encargo del supervicion de prueba', 1),
(6, 4, 1, '2026-06-17', 'para abastecimiento de Stock nuevo', 'Array', 1);

--
-- Disparadores `producciones`
--
DELIMITER $$
CREATE TRIGGER `trg_validar_fecha_produccion` BEFORE INSERT ON `producciones` FOR EACH ROW BEGIN

    IF NEW.fecha_produccion > CURDATE() THEN

        SIGNAL SQLSTATE '45000' 

        SET MESSAGE_TEXT = 'Error: No puede registrar una producci├│n con fecha futura.';

    END IF;

END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

CREATE TABLE `productos` (
  `id_producto` int(11) NOT NULL,
  `nombre_producto` varchar(100) NOT NULL,
  `precio_venta` float(11,2) NOT NULL,
  `stock` int(11) NOT NULL,
  `fecha_registro` date NOT NULL,
  `fecha_vencimiento` date NOT NULL,
  `id_categoria` int(11) NOT NULL,
  `imagen` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`id_producto`, `nombre_producto`, `precio_venta`, `stock`, `fecha_registro`, `fecha_vencimiento`, `id_categoria`, `imagen`, `status`) VALUES
(1, 'Galletas Natys dulces con sabor a Naranja 90g', 1.50, 200, '2026-06-01', '2026-12-30', 1, 'assets/img/productos/img6.png', 1),
(2, 'Galletas dulces Natys con sabor a coco 90g', 3.50, 1400, '2026-06-01', '2026-12-30', 1, 'assets/img/productos/img1.png', 1),
(3, 'Galletas Natys Saladitas queso chedar 90g', 2.00, 5100, '2026-06-01', '2026-12-30', 2, 'assets/img/productos/img3.png', 1),
(4, 'Galletas Natys dulces con sabor a Colita 90g', 2.50, 410, '2026-06-01', '2026-12-30', 1, 'assets/img/productos/img4.png', 1),
(5, 'Galletas Natys dulces con sabor a Limon 90g', 122.00, 600, '2026-06-12', '2026-07-01', 1, 'assets/img/productos/emp_limon-BKkbFTo6.png', 1),
(6, 'Galletas Natys dulces con sabor a Polvorosa 90g', 2.50, 50, '2026-06-16', '2026-07-12', 3, 'assets/img/productos/polvorosas.png', 1),
(7, 'Galletas Natys dulces con sabor a Panchi 90g', 54.00, 2, '2026-06-16', '2026-07-12', 2, 'assets/img/productos/panchi.png', 1);

--
-- Disparadores `productos`
--
DELIMITER $$
CREATE TRIGGER `trg_auditoria_borrado_producto` AFTER DELETE ON `productos` FOR EACH ROW BEGIN

    INSERT INTO larence_seguridad.bitacoras (id_usuario, modulo, accion, descripcion, fecha_bitacora) 

    VALUES (NULL, 'Productos', 'Borrado', CONCAT('Se elimin├│ el producto ID: ', OLD.id_producto, ' | Nombre: ', OLD.nombre_producto), NOW());

END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_auditoria_precio_producto` AFTER UPDATE ON `productos` FOR EACH ROW BEGIN

    -- Validamos si el precio realmente cambi├│

    IF OLD.precio_venta <> NEW.precio_venta THEN

        -- Insertamos en la base de datos de seguridad usando la notaci├│n base_datos.tabla

        INSERT INTO larence_seguridad.bitacoras (id_usuario, modulo, accion, descripcion, fecha_bitacora)

        VALUES (NULL, 'Productos', 'Modificar Precio', CONCAT('Se cambi├│ el precio del producto ID ', OLD.id_producto, ' de ', OLD.precio_venta, ' a ', NEW.precio_venta), NOW());

    END IF;

END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_validar_stock_positivo` BEFORE UPDATE ON `productos` FOR EACH ROW BEGIN

    IF NEW.stock < 0 THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT = 'ERROR: El stock no puede ser negativo, transacci├│n cancelada.';

    END IF;

END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `promociones`
--

CREATE TABLE `promociones` (
  `id_promocion` int(11) NOT NULL,
  `nombre_promocion` varchar(100) NOT NULL,
  `descripcion_promocion` varchar(100) NOT NULL,
  `fecha_inicio` date NOT NULL,
  `fecha_fin` date NOT NULL,
  `tipo_descuento` varchar(100) NOT NULL,
  `valor_descuento` float(11,2) NOT NULL,
  `estado` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `promociones`
--

INSERT INTO `promociones` (`id_promocion`, `nombre_promocion`, `descripcion_promocion`, `fecha_inicio`, `fecha_fin`, `tipo_descuento`, `valor_descuento`, `estado`, `status`) VALUES
(1, 'GALLETAS 2X1', 'promo de junio', '2026-06-12', '2026-07-02', 'porcentaje', 20.00, 1, 1),
(2, 'TODO PARA TI si', 'TODO ES PARA TI', '2026-06-12', '2026-07-08', '', 2.00, 1, 0),
(3, 'Promo flash', 'EN todas las galletas', '2026-06-16', '2026-06-21', '2x1', 2.00, 0, 1),
(4, 'promo fin de mes', 'en fin de mes', '2026-06-16', '2026-06-21', '2x1', 2.00, 0, 1),
(5, 'promo fin de mes', 'en todas la de coco', '2026-06-17', '2026-07-08', '2x1', 2.00, 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedores`
--

CREATE TABLE `proveedores` (
  `id_proveedor` int(11) NOT NULL,
  `tipo_id` varchar(11) NOT NULL,
  `nombre_proveedor` varchar(100) NOT NULL,
  `direccion_proveedor` varchar(100) NOT NULL,
  `tlf_proveedor` varchar(11) NOT NULL,
  `email_proveedor` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `proveedores`
--

INSERT INTO `proveedores` (`id_proveedor`, `tipo_id`, `nombre_proveedor`, `direccion_proveedor`, `tlf_proveedor`, `email_proveedor`, `status`) VALUES
(12321234, 'J-', 'Empresas Polar CA', 'Zona industrial II calle 1', '02513213490', 'polar_lara@gmail.com', 1),
(17100998, 'J-', 'Alimentos Lara CA', 'Zona industrial II calle 4', '02514408820', 'alimentoslara@gmail.com', 1),
(31039711, 'J-', 'Distribuidor la 21ca', 'Carrera 21 con calle 29', '02513213495', 'Dis21ca@gmail.com', 1),
(478475938, 'J-', 'La FRIZ', 'Carrera 21 con calle 29', '02513213495', 'friz@gmail.com', 1),
(987234923, 'J-', 'La especial ca', 'Carrera 21 con calle 29 y 30', '02513213495', 'Laespecial@gmail.com', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tasa_dia`
--

CREATE TABLE `tasa_dia` (
  `id_tasa` int(11) NOT NULL,
  `moneda_tasa` varchar(50) NOT NULL,
  `monto_tasa` float(11,2) NOT NULL,
  `fecha_tasa` datetime(6) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `tasa_dia`
--

INSERT INTO `tasa_dia` (`id_tasa`, `moneda_tasa`, `monto_tasa`, `fecha_tasa`, `status`) VALUES
(1, '', 36.50, '2026-06-11 08:00:00.000000', 1),
(2, '', 593.00, '2026-06-16 17:18:16.000000', 1),
(3, 'USDT', 797.75, '2026-06-17 16:36:25.000000', 1),
(4, 'USD', 596.79, '2026-06-17 16:37:09.000000', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipos_clientes`
--

CREATE TABLE `tipos_clientes` (
  `id_tipo_cliente` int(11) NOT NULL,
  `nombre_tipo_cliente` varchar(100) NOT NULL,
  `dias_credito` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `tipos_clientes`
--

INSERT INTO `tipos_clientes` (`id_tipo_cliente`, `nombre_tipo_cliente`, `dias_credito`, `status`) VALUES
(1, 'Bodegas', 7, 1),
(2, 'Empresas', 15, 1),
(3, 'Distribuidores', 30, 1),
(4, 'Sucursales', 30, 1),
(5, 'Franquicia multiple', 15, 1),
(6, 'Grupo Japones', 16, 0),
(7, 'Quiosco', 7, 0),
(8, 'Particulares', 7, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `unidad_medidas`
--

CREATE TABLE `unidad_medidas` (
  `id_unidad_medida` int(11) NOT NULL,
  `nombre_medida` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `unidad_medidas`
--

INSERT INTO `unidad_medidas` (`id_unidad_medida`, `nombre_medida`) VALUES
(1, 'Sacos'),
(2, 'Bultos'),
(3, 'Kilogramos'),
(4, 'Litros'),
(5, 'Cajas');

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_clientes_vip`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_clientes_vip` (
`id_cliente` int(11)
,`gastado` double(19,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_seguimiento_produccion`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_seguimiento_produccion` (
`id_produccion` int(11)
,`nombre_producto` varchar(100)
,`cantidad_producida` int(11)
,`fecha_produccion` date
,`materia_prima_estimada_usada` decimal(12,1)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_stock_critico_natys`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_stock_critico_natys` (
`id_producto` int(11)
,`nombre_producto` varchar(100)
,`precio_venta` float(11,2)
,`stock` int(11)
,`nombre_categoria` varchar(100)
);

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_clientes_vip`
--
DROP TABLE IF EXISTS `vista_clientes_vip`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_clientes_vip`  AS SELECT `p`.`id_cliente` AS `id_cliente`, sum(`dp`.`cantidad` * `dp`.`precio_unitario`) AS `gastado` FROM (`pedidos` `p` join `detalle_pedidos` `dp` on(`p`.`id_pedido` = `dp`.`id_pedido`)) GROUP BY `p`.`id_cliente` HAVING `gastado` > 1000 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_seguimiento_produccion`
--
DROP TABLE IF EXISTS `vista_seguimiento_produccion`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_seguimiento_produccion`  AS SELECT `prod`.`id_produccion` AS `id_produccion`, `p`.`nombre_producto` AS `nombre_producto`, `prod`.`cantidad_producida` AS `cantidad_producida`, `prod`.`fecha_produccion` AS `fecha_produccion`, `prod`.`cantidad_producida`* 0.5 AS `materia_prima_estimada_usada` FROM (`producciones` `prod` join `productos` `p` on(`prod`.`id_producto` = `p`.`id_producto`)) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_stock_critico_natys`
--
DROP TABLE IF EXISTS `vista_stock_critico_natys`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_stock_critico_natys`  AS SELECT `p`.`id_producto` AS `id_producto`, `p`.`nombre_producto` AS `nombre_producto`, `p`.`precio_venta` AS `precio_venta`, `p`.`stock` AS `stock`, `c`.`nombre_categoria` AS `nombre_categoria` FROM (`productos` `p` join `categorias` `c` on(`p`.`id_categoria` = `c`.`id_categoria`)) WHERE `p`.`stock` < 50 ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `categorias`
--
ALTER TABLE `categorias`
  ADD PRIMARY KEY (`id_categoria`);

--
-- Indices de la tabla `clientes`
--
ALTER TABLE `clientes`
  ADD PRIMARY KEY (`id_cliente`),
  ADD KEY `id_tipo_cliente` (`id_tipo_cliente`);

--
-- Indices de la tabla `compras`
--
ALTER TABLE `compras`
  ADD PRIMARY KEY (`id_compra`),
  ADD KEY `id_proveedor` (`id_proveedor`),
  ADD KEY `id_tasa` (`id_tasa`),
  ADD KEY `id_estado_pago` (`id_estado_pago`);

--
-- Indices de la tabla `cuenta_x_cobrar`
--
ALTER TABLE `cuenta_x_cobrar`
  ADD PRIMARY KEY (`id_cuenta_x_cobrar`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_cliente` (`id_cliente`);

--
-- Indices de la tabla `cuenta_x_pagar`
--
ALTER TABLE `cuenta_x_pagar`
  ADD PRIMARY KEY (`id_cuenta_x_pagar`),
  ADD KEY `id_compra` (`id_compra`),
  ADD KEY `id_proveedor` (`id_proveedor`);

--
-- Indices de la tabla `detalles_entregas`
--
ALTER TABLE `detalles_entregas`
  ADD PRIMARY KEY (`id_detalle_entrega`),
  ADD KEY `id_entrega` (`id_entrega`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_cliente` (`id_cliente`);

--
-- Indices de la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  ADD PRIMARY KEY (`id_detalle_compra`),
  ADD KEY `id_compra` (`id_compra`),
  ADD KEY `id_materia_prima` (`id_materia_prima`);

--
-- Indices de la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  ADD PRIMARY KEY (`id_detalle_pedido`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_producto` (`id_producto`);

--
-- Indices de la tabla `detalle_producciones`
--
ALTER TABLE `detalle_producciones`
  ADD PRIMARY KEY (`id_detalle_produccion`),
  ADD KEY `id_produccion` (`id_produccion`),
  ADD KEY `id_materia_prima` (`id_materia_prima`);

--
-- Indices de la tabla `detalle_promocion`
--
ALTER TABLE `detalle_promocion`
  ADD PRIMARY KEY (`id_detalle_promocion`),
  ADD KEY `id_promocion` (`id_promocion`),
  ADD KEY `id_producto` (`id_producto`);

--
-- Indices de la tabla `entregas`
--
ALTER TABLE `entregas`
  ADD PRIMARY KEY (`id_entregas`),
  ADD KEY `id_estado_entrega` (`id_estado_entrega`),
  ADD KEY `fecha_entrega_programada` (`fecha_entrega_programada`);

--
-- Indices de la tabla `entrega_pedidos`
--
ALTER TABLE `entrega_pedidos`
  ADD PRIMARY KEY (`id_entrega_pedido`),
  ADD KEY `idx_ep_entrega` (`id_entrega`),
  ADD KEY `idx_ep_pedido` (`id_pedido`);

--
-- Indices de la tabla `estado_entrega`
--
ALTER TABLE `estado_entrega`
  ADD PRIMARY KEY (`id_estado_entrega`);

--
-- Indices de la tabla `estado_pago`
--
ALTER TABLE `estado_pago`
  ADD PRIMARY KEY (`id_estado_pago`);

--
-- Indices de la tabla `estado_pedido`
--
ALTER TABLE `estado_pedido`
  ADD PRIMARY KEY (`id_estado_pedido`);

--
-- Indices de la tabla `materia_prima`
--
ALTER TABLE `materia_prima`
  ADD PRIMARY KEY (`id_materia_prima`),
  ADD KEY `id_unidad_medida` (`id_unidad_medida`),
  ADD KEY `id_proveedor` (`id_proveedor`);

--
-- Indices de la tabla `metodos_pago`
--
ALTER TABLE `metodos_pago`
  ADD PRIMARY KEY (`id_metodo_pago`);

--
-- Indices de la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD PRIMARY KEY (`id_pago`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_metodo_pago` (`id_metodo_pago`);

--
-- Indices de la tabla `pagos_proveedores`
--
ALTER TABLE `pagos_proveedores`
  ADD PRIMARY KEY (`id_pago_proveedor`),
  ADD KEY `id_cuenta_x_pagar` (`id_cuenta_x_pagar`),
  ADD KEY `id_metodo_pago` (`id_metodo_pago`);

--
-- Indices de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD PRIMARY KEY (`id_pedido`),
  ADD KEY `id_cliente` (`id_cliente`),
  ADD KEY `id_estado_pedido` (`id_estado_pedido`),
  ADD KEY `id_estado_pago` (`id_estado_pago`),
  ADD KEY `id_tasa` (`id_tasa`),
  ADD KEY `id_promocion` (`id_promocion`),
  ADD KEY `fecha_pedido` (`fecha_pedido`);

--
-- Indices de la tabla `producciones`
--
ALTER TABLE `producciones`
  ADD PRIMARY KEY (`id_produccion`),
  ADD KEY `id_producto` (`id_producto`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id_producto`),
  ADD KEY `id_categoria` (`id_categoria`);

--
-- Indices de la tabla `promociones`
--
ALTER TABLE `promociones`
  ADD PRIMARY KEY (`id_promocion`);

--
-- Indices de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  ADD PRIMARY KEY (`id_proveedor`);

--
-- Indices de la tabla `tasa_dia`
--
ALTER TABLE `tasa_dia`
  ADD PRIMARY KEY (`id_tasa`);

--
-- Indices de la tabla `tipos_clientes`
--
ALTER TABLE `tipos_clientes`
  ADD PRIMARY KEY (`id_tipo_cliente`);

--
-- Indices de la tabla `unidad_medidas`
--
ALTER TABLE `unidad_medidas`
  ADD PRIMARY KEY (`id_unidad_medida`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `categorias`
--
ALTER TABLE `categorias`
  MODIFY `id_categoria` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `clientes`
--
ALTER TABLE `clientes`
  MODIFY `id_cliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=363653677;

--
-- AUTO_INCREMENT de la tabla `compras`
--
ALTER TABLE `compras`
  MODIFY `id_compra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `cuenta_x_cobrar`
--
ALTER TABLE `cuenta_x_cobrar`
  MODIFY `id_cuenta_x_cobrar` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT de la tabla `cuenta_x_pagar`
--
ALTER TABLE `cuenta_x_pagar`
  MODIFY `id_cuenta_x_pagar` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `detalles_entregas`
--
ALTER TABLE `detalles_entregas`
  MODIFY `id_detalle_entrega` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  MODIFY `id_detalle_compra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  MODIFY `id_detalle_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- AUTO_INCREMENT de la tabla `detalle_producciones`
--
ALTER TABLE `detalle_producciones`
  MODIFY `id_detalle_produccion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT de la tabla `detalle_promocion`
--
ALTER TABLE `detalle_promocion`
  MODIFY `id_detalle_promocion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `entregas`
--
ALTER TABLE `entregas`
  MODIFY `id_entregas` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT de la tabla `entrega_pedidos`
--
ALTER TABLE `entrega_pedidos`
  MODIFY `id_entrega_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `estado_entrega`
--
ALTER TABLE `estado_entrega`
  MODIFY `id_estado_entrega` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `estado_pago`
--
ALTER TABLE `estado_pago`
  MODIFY `id_estado_pago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `estado_pedido`
--
ALTER TABLE `estado_pedido`
  MODIFY `id_estado_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `materia_prima`
--
ALTER TABLE `materia_prima`
  MODIFY `id_materia_prima` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `metodos_pago`
--
ALTER TABLE `metodos_pago`
  MODIFY `id_metodo_pago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `pagos`
--
ALTER TABLE `pagos`
  MODIFY `id_pago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT de la tabla `pagos_proveedores`
--
ALTER TABLE `pagos_proveedores`
  MODIFY `id_pago_proveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  MODIFY `id_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT de la tabla `producciones`
--
ALTER TABLE `producciones`
  MODIFY `id_produccion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `promociones`
--
ALTER TABLE `promociones`
  MODIFY `id_promocion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  MODIFY `id_proveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=987234924;

--
-- AUTO_INCREMENT de la tabla `tasa_dia`
--
ALTER TABLE `tasa_dia`
  MODIFY `id_tasa` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `tipos_clientes`
--
ALTER TABLE `tipos_clientes`
  MODIFY `id_tipo_cliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT de la tabla `unidad_medidas`
--
ALTER TABLE `unidad_medidas`
  MODIFY `id_unidad_medida` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `clientes`
--
ALTER TABLE `clientes`
  ADD CONSTRAINT `clientes_ibfk_1` FOREIGN KEY (`id_tipo_cliente`) REFERENCES `tipos_clientes` (`id_tipo_cliente`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `compras`
--
ALTER TABLE `compras`
  ADD CONSTRAINT `compras_ibfk_1` FOREIGN KEY (`id_proveedor`) REFERENCES `proveedores` (`id_proveedor`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `compras_ibfk_2` FOREIGN KEY (`id_tasa`) REFERENCES `tasa_dia` (`id_tasa`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `compras_ibfk_3` FOREIGN KEY (`id_estado_pago`) REFERENCES `estado_pago` (`id_estado_pago`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `cuenta_x_cobrar`
--
ALTER TABLE `cuenta_x_cobrar`
  ADD CONSTRAINT `cuenta_x_cobrar_ibfk_1` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `cuenta_x_cobrar_ibfk_2` FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id_cliente`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `cuenta_x_pagar`
--
ALTER TABLE `cuenta_x_pagar`
  ADD CONSTRAINT `cuenta_x_pagar_ibfk_1` FOREIGN KEY (`id_compra`) REFERENCES `compras` (`id_compra`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `cuenta_x_pagar_ibfk_2` FOREIGN KEY (`id_proveedor`) REFERENCES `proveedores` (`id_proveedor`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalles_entregas`
--
ALTER TABLE `detalles_entregas`
  ADD CONSTRAINT `detalles_entregas_ibfk_1` FOREIGN KEY (`id_entrega`) REFERENCES `entregas` (`id_entregas`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalles_entregas_ibfk_2` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalles_entregas_ibfk_3` FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id_cliente`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  ADD CONSTRAINT `detalle_compras_ibfk_1` FOREIGN KEY (`id_compra`) REFERENCES `compras` (`id_compra`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_compras_ibfk_2` FOREIGN KEY (`id_materia_prima`) REFERENCES `materia_prima` (`id_materia_prima`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  ADD CONSTRAINT `detalle_pedidos_ibfk_1` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_pedidos_ibfk_2` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_producciones`
--
ALTER TABLE `detalle_producciones`
  ADD CONSTRAINT `detalle_producciones_ibfk_1` FOREIGN KEY (`id_produccion`) REFERENCES `producciones` (`id_produccion`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_producciones_ibfk_2` FOREIGN KEY (`id_materia_prima`) REFERENCES `materia_prima` (`id_materia_prima`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_promocion`
--
ALTER TABLE `detalle_promocion`
  ADD CONSTRAINT `detalle_promocion_ibfk_1` FOREIGN KEY (`id_promocion`) REFERENCES `promociones` (`id_promocion`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_promocion_ibfk_2` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `entregas`
--
ALTER TABLE `entregas`
  ADD CONSTRAINT `entregas_ibfk_1` FOREIGN KEY (`id_estado_entrega`) REFERENCES `estado_entrega` (`id_estado_entrega`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `materia_prima`
--
ALTER TABLE `materia_prima`
  ADD CONSTRAINT `materia_prima_ibfk_1` FOREIGN KEY (`id_unidad_medida`) REFERENCES `unidad_medidas` (`id_unidad_medida`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `materia_prima_ibfk_2` FOREIGN KEY (`id_proveedor`) REFERENCES `proveedores` (`id_proveedor`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD CONSTRAINT `pagos_ibfk_1` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `pagos_ibfk_2` FOREIGN KEY (`id_metodo_pago`) REFERENCES `metodos_pago` (`id_metodo_pago`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `pagos_proveedores`
--
ALTER TABLE `pagos_proveedores`
  ADD CONSTRAINT `pagos_proveedores_ibfk_1` FOREIGN KEY (`id_cuenta_x_pagar`) REFERENCES `cuenta_x_pagar` (`id_cuenta_x_pagar`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `pagos_proveedores_ibfk_2` FOREIGN KEY (`id_metodo_pago`) REFERENCES `metodos_pago` (`id_metodo_pago`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD CONSTRAINT `pedidos_ibfk_1` FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id_cliente`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `pedidos_ibfk_2` FOREIGN KEY (`id_estado_pedido`) REFERENCES `estado_pedido` (`id_estado_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `pedidos_ibfk_3` FOREIGN KEY (`id_estado_pago`) REFERENCES `estado_pago` (`id_estado_pago`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `pedidos_ibfk_4` FOREIGN KEY (`id_tasa`) REFERENCES `tasa_dia` (`id_tasa`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `producciones`
--
ALTER TABLE `producciones`
  ADD CONSTRAINT `producciones_ibfk_1` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `productos`
--
ALTER TABLE `productos`
  ADD CONSTRAINT `productos_ibfk_1` FOREIGN KEY (`id_categoria`) REFERENCES `categorias` (`id_categoria`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
