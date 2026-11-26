-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 18-11-2026 a las 22:50:40
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
CREATE DEFINER=`root`@`localhost` PROCEDURE `aplicar_descuento_volumen` (IN `p_id_detalle` INT(11))   BEGIN



    UPDATE detalles_pedido 



    SET precio_unitario = precio_unitario * 0.90 



    WHERE id_detalle = p_id_detalle 



    AND cantidad > 50;



END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `calcular_total_con_iva` (IN `p_id_pedido` INT, OUT `p_total_final` DECIMAL(10,2))   BEGIN



    DECLARE v_subtotal DECIMAL(10,2);



    



    SELECT total INTO v_subtotal 



    FROM pedidos 



    WHERE id_pedido = p_id_pedido;



    



    SET p_total_final = v_subtotal * 1.16;



END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `generar_reporte_ventas_dia` (IN `p_fecha` DATE)   BEGIN



    SELECT p.nombre_producto, 



           SUM(dp.cantidad) as total_vendido, 



           SUM(dp.cantidad * dp.precio_unitario) as monto_total



    FROM productos p



    JOIN detalles_pedido dp ON p.id_producto = dp.id_producto



    JOIN pedidos ped ON dp.id_pedido = ped.id_pedido



    WHERE ped.fecha_pedido = p_fecha



    GROUP BY p.nombre_producto;



END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `registrar_pedido_seguro` (IN `p_id_cliente` INT, IN `p_id_producto` INT, IN `p_cantidad` INT, IN `p_precio` DECIMAL(10,2), OUT `p_mensaje` VARCHAR(100))   BEGIN



    DECLARE v_stock_actual INT;



    



    -- Manejador de errores (Si algo falla, hace ROLLBACK)



    DECLARE EXIT HANDLER FOR SQLEXCEPTION



    BEGIN



        ROLLBACK;



        SET p_mensaje = 'Error en la transacción. Cambios revertidos.';



    END;







    -- Iniciamos la transacción



    START TRANSACTION;



    



    -- Bloqueamos la fila del producto para evitar lecturas fantasmas



    SELECT stock INTO v_stock_actual FROM larence.productos WHERE id_producto = p_id_producto FOR UPDATE;



    



    IF v_stock_actual >= p_cantidad THEN



        -- Descontamos el inventario



        UPDATE larence.productos SET stock = stock - p_cantidad WHERE id_producto = p_id_producto;



        



        -- Confirmamos los cambios



        COMMIT;



        SET p_mensaje = 'Pedido registrado y stock descontado con éxito.';



    ELSE



        ROLLBACK;



        SET p_mensaje = 'Transacción rechazada: Stock insuficiente en almacén.';



    END IF;



END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_actualizar_tasa_cambio` (IN `p_moneda` VARCHAR(50), IN `p_monto` DECIMAL(10,2))   BEGIN

    INSERT INTO tasa_dia (moneda_tasa, monto_tasa, fecha_tasa, status)

    VALUES (p_moneda, p_monto, NOW(), 1);

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_anular_pedido` (IN `p_id_pedido` INT)   BEGIN

    DECLARE done INT DEFAULT FALSE;

    DECLARE v_id_producto INT;

    DECLARE v_cantidad INT;

    

    DECLARE cur CURSOR FOR 

        SELECT id_producto, cantidad FROM detalle_pedidos WHERE id_pedido = p_id_pedido;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;



    START TRANSACTION;



    -- Devolver stock de los productos del pedido

    OPEN cur;

    read_loop: LOOP

        FETCH cur INTO v_id_producto, v_cantidad;

        IF done THEN

            LEAVE read_loop;

        END IF;

        UPDATE productos SET stock = stock + v_cantidad WHERE id_producto = v_id_producto;

    END LOOP;

    CLOSE cur;



    -- Cambiar estatus del pedido

    UPDATE pedidos SET status = 0 WHERE id_pedido = p_id_pedido;



    COMMIT;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_pago_cliente` (IN `p_id_pedido` INT, IN `p_monto` DECIMAL(10,2), IN `p_nro_ref` VARCHAR(11), IN `p_metodo` INT, IN `p_concepto` VARCHAR(200), IN `p_img` VARCHAR(100))   BEGIN

    -- Insertar el pago

    INSERT INTO pagos (id_pedido, monto_pago, fecha_pago, nro_referencia, concepto, id_metodo_pago, img_pago)

    VALUES (p_id_pedido, p_monto, NOW(), p_nro_ref, p_concepto, p_metodo, p_img);



    -- Actualizar la cuenta por cobrar

    UPDATE cuenta_x_cobrar 

    SET saldo_pendiente = GREATEST(0, saldo_pendiente - p_monto),

        estado_cuenta = IF(saldo_pendiente - p_monto <= 0, 'Pagado', 'Por Pagar')

    WHERE id_pedido = p_id_pedido;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_produccion` (IN `p_id_producto` INT, IN `p_cantidad` INT, IN `p_fecha` DATE, IN `p_motivo` VARCHAR(100), IN `p_observacion` VARCHAR(100))   BEGIN

    START TRANSACTION;



    -- Insertar en la tabla producciones

    INSERT INTO producciones (id_producto, cantidad_producida, fecha_produccion, motivo_produccion, observacion, status)

    VALUES (p_id_producto, p_cantidad, p_fecha, p_motivo, p_observacion, 1);



    -- Aumentar el stock en productos

    UPDATE productos 

    SET stock = stock + p_cantidad 

    WHERE id_producto = p_id_producto;



    COMMIT;

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



    



    -- Buscar la tasa activa más reciente



    SELECT monto_tasa INTO v_tasa_actual FROM larence.tasa_dia WHERE status = 1 ORDER BY id_tasa DESC LIMIT 1;



    



    -- Calcular



    SET v_precio_final = p_precio_dolares * v_tasa_actual;



    



    RETURN v_precio_final;



END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_calcular_monto_dolares` (`p_monto_bs` DECIMAL(10,2)) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN

    DECLARE v_tasa DECIMAL(10,2);

    DECLARE v_resultado DECIMAL(10,2);

    

    SELECT monto_tasa INTO v_tasa 

    FROM tasa_dia 

    WHERE status = 1 

    ORDER BY id_tasa DESC LIMIT 1;

    

    IF v_tasa IS NULL OR v_tasa = 0 THEN

        RETURN 0.00;

    END IF;

    

    SET v_resultado = p_monto_bs / v_tasa;

    RETURN v_resultado;

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_descuento_promocion_activa` (`p_id_promocion` INT) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN

    DECLARE v_descuento DECIMAL(10,2) DEFAULT 0.00;

    

    SELECT valor_descuento INTO v_descuento 

    FROM promociones 

    WHERE id_promocion = p_id_promocion AND estado = 1 AND status = 1;

    

    RETURN IFNULL(v_descuento, 0.00);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_dias_credito_cliente` (`p_id_cliente` INT) RETURNS INT(11) READS SQL DATA BEGIN

    DECLARE v_dias INT DEFAULT 0;

    

    SELECT tc.dias_credito INTO v_dias

    FROM clientes c

    JOIN tipos_clientes tc ON c.id_tipo_cliente = tc.id_tipo_cliente

    WHERE c.id_cliente = p_id_cliente;

    

    RETURN IFNULL(v_dias, 0);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_formato_identificacion` (`p_tipo` VARCHAR(11), `p_id` INT) RETURNS VARCHAR(50) CHARSET latin1 COLLATE latin1_swedish_ci DETERMINISTIC BEGIN

    RETURN CONCAT(UPPER(p_tipo), '-', p_id);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_obtener_stock_producto` (`p_id_producto` INT) RETURNS INT(11) READS SQL DATA BEGIN

    DECLARE v_stock INT DEFAULT 0;

    

    SELECT stock INTO v_stock 

    FROM productos 

    WHERE id_producto = p_id_producto;

    

    RETURN IFNULL(v_stock, 0);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_saldo_pendiente_cliente` (`p_id_cliente` INT) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN

    DECLARE v_saldo DECIMAL(10,2) DEFAULT 0.00;

    

    SELECT SUM(saldo_pendiente) INTO v_saldo 

    FROM cuenta_x_cobrar 

    WHERE id_cliente = p_id_cliente AND estado_cuenta = 'Por Pagar' AND status = 1;

    

    RETURN IFNULL(v_saldo, 0.00);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_total_compras_mes` (`p_mes` INT, `p_anio` INT) RETURNS DECIMAL(10,2) READS SQL DATA BEGIN

    DECLARE v_total DECIMAL(10,2) DEFAULT 0.00;

    

    SELECT SUM(monto_total_compra) INTO v_total 

    FROM compras 

    WHERE MONTH(fecha_compra) = p_mes 

      AND YEAR(fecha_compra) = p_anio 

      AND status = 1;

      

    RETURN IFNULL(v_total, 0.00);

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_total_producido_producto` (`p_id_producto` INT) RETURNS INT(11) READS SQL DATA BEGIN

    DECLARE v_total_producido INT DEFAULT 0;

    

    SELECT SUM(cantidad_producida) INTO v_total_producido 

    FROM producciones 

    WHERE id_producto = p_id_producto AND status = 1;

    

    RETURN IFNULL(v_total_producido, 0);

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `camiones`
--

CREATE TABLE `camiones` (
  `id_camion` int(11) NOT NULL,
  `placa` varchar(10) NOT NULL,
  `modelo_marca` varchar(50) NOT NULL,
  `capacidad_peso_kg` decimal(10,2) NOT NULL DEFAULT 0.00,
  `capacidad_cajas` int(11) NOT NULL DEFAULT 0,
  `estado` enum('disponible','en_ruta','mantenimiento','inactivo') NOT NULL DEFAULT 'disponible',
  `status` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `camiones`
--

INSERT INTO `camiones` (`id_camion`, `placa`, `modelo_marca`, `capacidad_peso_kg`, `capacidad_cajas`, `estado`, `status`) VALUES
(1, 'ABC123', 'Toyota Hiace 2019', 2500.00, 300, 'disponible', 1),
(2, 'DEF456', 'Nissan Frontier 2020', 3000.00, 200, 'disponible', 1),
(3, 'GHI789', 'Foton Aumark 2021', 1500.00, 100, 'disponible', 1),
(4, 'JKL012', 'Ford Transit 2018', 1200.00, 150, 'mantenimiento', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `carrito`
--

CREATE TABLE `carrito` (
  `id_carrito` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `id_cliente` int(11) DEFAULT NULL,
  `fecha_creacion` datetime NOT NULL DEFAULT current_timestamp(),
  `estado` enum('activo','convertido','cancelado') NOT NULL DEFAULT 'activo',
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `carrito`
--

INSERT INTO `carrito` (`id_carrito`, `id_usuario`, `id_cliente`, `fecha_creacion`, `estado`, `status`) VALUES
(1, 2, NULL, '2026-11-17 16:37:25', 'activo', 1);

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
(4, 'Reposteria', 1);

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
  `fecha_registro` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `img_cliente` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `clientes`
--

INSERT INTO `clientes` (`id_cliente`, `tipo_id`, `id_tipo_cliente`, `nombre_cliente`, `direccion_cliente`, `sector`, `tlf_cliente`, `email_cliente`, `estado_cliente`, `fecha_registro`, `img_cliente`, `status`) VALUES
(14555666, 'V', 8, 'Carmen Rodriguez', 'Urb Del Este, calle 5', 'Este', '04120001107', 'cliente14555666@example.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(17100998, 'J', 2, 'Farmatodo', 'Av Pedro leon con calle 54', 'Oeste', '02511358621', 'farmatodo@gmail.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/farmatodo.png', 1),
(19888777, 'V', 8, 'Luis Colmenarez', 'Barrio El Jebe, calle 3', 'Sur', '04120001108', 'cliente19888777@example.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(25566580, 'V', 1, 'Juan Perez', 'Urb Eligio Macias Mujica Calle 3', 'Sur', '04122373562', 'yijofo1151@hotkev.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(25566582, 'V', 1, 'Miguel Bose', 'Urb Eligio Macias Mujica Calle 3', 'Sur', '04122373562', 'eliasarmas0902@gmail.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/FONDO.jpg', 1),
(25566585, 'V', 1, 'Jesus andrade', 'Urb Eligio Macias Mujica Calle 3', 'Sur', '04122373562', 'eliasarmas0902@gmail.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(30111222, 'J', 1, 'Bodega El Rinconcito', 'Carrera 19 con calle 30', 'Centro', '04120001101', 'cliente30111222@example.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(30222333, 'J', 1, 'Abastos La Esquina Feliz', 'Calle 42 entre carreras 25 y 26', 'Oeste', '04120001102', 'cliente30222333@example.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(30333444, 'J', 3, 'Distribuidora Dulce Lara', 'Zona Industrial I, galpon 8', 'Este', '02510001103', 'cliente30333444@example.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(30444555, 'J', 2, 'Panaderia Santa Rosa', 'Av Principal de Santa Rosa', 'Este', '02510001104', 'cliente30444555@example.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(30555666, 'J', 7, 'Kiosco Plaza Bolivar', 'Plaza Bolivar, local 2', 'Centro', '04120001105', 'cliente30555666@example.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(30666777, 'J', 3, 'Comercial Tres Hermanos', 'Av Venezuela con calle 12', 'Norte', '02510001106', 'cliente30666777@example.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/descarga.jpg', 1),
(31039811, 'J', 4, 'PaTodo', 'Av Urb Patarata con Calle 20', 'Centro', '02513213495', 'patodo@gmail.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/patodo.jpg', 1),
(32200771, 'J', 3, 'Mi Super ca', 'Calle 54 con Carrera 20', 'Oeste', '02514408820', 'misuper@gmail.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/miSuper.png', 1),
(33220448, 'V', 5, 'Gabriela Hernandez', 'la rotaria', 'Oeste', '04245064176', 'mariagabrielahm08@gmail.com', 'Activo', '2026-01-02 08:00:00.000000', 'assets/img/clientes/WIN_20260329_18_31_33_Pro.jpg', 1),
(33220449, 'V', 1, '@superusuario_24', 'Sistema', 'Norte', '04120000000', 'moises2005pereira@gmail.com', 'Activo', '2026-01-02 08:00:00.000000', 'Assets/img/perfiles/perfil_2_1781140325.jpg', 1),
(171009980, 'J', 2, 'Cliente la rosa 2', 'Carrera 20 entre calles 9 y 10', 'Este', '04121232343', 'larosa@gmail.com', 'Anulado', '2026-11-17 01:01:34.316734', '', 1);

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
(1, 12321234, '2026-01-02 00:00:00.000000', 1588.00, 1, 2, 'Compra mensual: Harina, Margarina', 1),
(2, 17100998, '2026-01-02 00:00:00.000000', 168.00, 1, 2, 'Compra mensual: Huevos', 1),
(3, 31039711, '2026-01-02 00:00:00.000000', 319.00, 1, 2, 'Compra mensual: Azucar', 1),
(4, 12321234, '2026-02-02 00:00:00.000000', 891.00, 3, 2, 'Compra mensual: Harina, Margarina', 1),
(5, 17100998, '2026-02-02 00:00:00.000000', 92.00, 3, 2, 'Compra mensual: Huevos', 1),
(6, 31039711, '2026-02-02 00:00:00.000000', 165.00, 3, 2, 'Compra mensual: Azucar', 1),
(7, 12321234, '2026-03-02 00:00:00.000000', 1098.00, 5, 2, 'Compra mensual: Harina, Margarina', 1),
(8, 17100998, '2026-03-02 00:00:00.000000', 116.00, 5, 2, 'Compra mensual: Huevos', 1),
(9, 31039711, '2026-03-02 00:00:00.000000', 220.00, 5, 1, 'Compra mensual: Azucar', 1),
(10, 12321234, '2026-04-01 00:00:00.000000', 964.00, 7, 2, 'Compra mensual: Harina, Margarina', 1),
(11, 17100998, '2026-04-01 00:00:00.000000', 104.00, 7, 2, 'Compra mensual: Huevos', 1),
(12, 31039711, '2026-04-01 00:00:00.000000', 209.00, 7, 2, 'Compra mensual: Azucar', 1),
(13, 12321234, '2026-05-01 00:00:00.000000', 1208.00, 9, 2, 'Compra mensual: Harina, Margarina', 1),
(14, 17100998, '2026-05-01 00:00:00.000000', 128.00, 9, 2, 'Compra mensual: Huevos', 1),
(15, 31039711, '2026-05-01 00:00:00.000000', 187.00, 9, 2, 'Compra mensual: Azucar', 1),
(16, 12321234, '2026-06-01 00:00:00.000000', 964.00, 11, 2, 'Compra mensual: Harina, Margarina', 1),
(17, 17100998, '2026-06-01 00:00:00.000000', 104.00, 11, 2, 'Compra mensual: Huevos', 1),
(18, 31039711, '2026-06-01 00:00:00.000000', 187.00, 11, 2, 'Compra mensual: Azucar', 1),
(19, 12321234, '2026-07-01 00:00:00.000000', 1330.00, 13, 2, 'Compra mensual: Harina, Margarina', 1),
(20, 17100998, '2026-07-01 00:00:00.000000', 140.00, 13, 2, 'Compra mensual: Huevos', 1),
(21, 31039711, '2026-07-01 00:00:00.000000', 220.00, 13, 2, 'Compra mensual: Azucar', 1),
(22, 12321234, '2026-08-01 00:00:00.000000', 1318.00, 15, 2, 'Compra mensual: Harina, Margarina', 1),
(23, 17100998, '2026-08-01 00:00:00.000000', 136.00, 15, 2, 'Compra mensual: Huevos', 1),
(24, 31039711, '2026-08-01 00:00:00.000000', 209.00, 15, 2, 'Compra mensual: Azucar', 1),
(25, 12321234, '2026-09-01 00:00:00.000000', 1147.00, 17, 2, 'Compra mensual: Harina, Margarina', 1),
(26, 17100998, '2026-09-01 00:00:00.000000', 120.00, 17, 2, 'Compra mensual: Huevos', 1),
(27, 31039711, '2026-09-01 00:00:00.000000', 209.00, 17, 2, 'Compra mensual: Azucar', 1),
(28, 12321234, '2026-10-01 00:00:00.000000', 964.00, 19, 2, 'Compra mensual: Harina, Margarina', 1),
(29, 17100998, '2026-10-01 00:00:00.000000', 104.00, 19, 2, 'Compra mensual: Huevos', 1),
(30, 31039711, '2026-10-01 00:00:00.000000', 154.00, 19, 1, 'Compra mensual: Azucar', 1),
(31, 12321234, '2026-11-02 00:00:00.000000', 586.00, 21, 1, 'Compra mensual: Harina, Margarina', 1),
(32, 17100998, '2026-11-02 00:00:00.000000', 60.00, 21, 1, 'Compra mensual: Huevos', 1),
(33, 31039711, '2026-11-02 00:00:00.000000', 121.00, 21, 1, 'Compra mensual: Azucar', 1);

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
(1, 1, 30444555, 740.00, 0.00, '2026-01-06', '2026-02-05', 'Pagado', 1),
(2, 2, 17100998, 360.00, 0.00, '2026-01-06', '2026-02-05', 'Pagado', 1),
(3, 3, 17100998, 535.00, 0.00, '2026-01-09', '2026-02-08', 'Pagado', 1),
(4, 4, 25566585, 650.00, 0.00, '2026-01-17', '2026-02-16', 'Pagado', 1),
(5, 5, 30333444, 469.00, 0.00, '2026-01-17', '2026-02-16', 'Pagado', 1),
(6, 6, 32200771, 490.00, 0.00, '2026-01-19', '2026-02-18', 'Pagado', 1),
(7, 7, 31039811, 330.00, 0.00, '2026-01-19', '2026-02-18', 'Pagado', 1),
(8, 8, 30222333, 650.00, 0.00, '2026-01-21', '2026-02-20', 'Pagado', 1),
(9, 9, 30444555, 650.00, 0.00, '2026-01-24', '2026-02-23', 'Pagado', 1),
(10, 10, 30555666, 515.00, 0.00, '2026-01-26', '2026-02-25', 'Pagado', 1),
(11, 11, 30555666, 525.50, 0.00, '2026-01-26', '2026-02-25', 'Pagado', 1),
(12, 12, 32200771, 360.00, 0.00, '2026-01-28', '2026-02-27', 'Pagado', 1),
(13, 13, 30555666, 210.00, 0.00, '2026-02-07', '2026-03-09', 'Pagado', 1),
(14, 14, 30333444, 575.00, 0.00, '2026-02-09', '2026-03-11', 'Pagado', 1),
(15, 15, 31039811, 650.00, 0.00, '2026-02-13', '2026-03-15', 'Pagado', 1),
(16, 16, 30444555, 675.00, 0.00, '2026-02-13', '2026-03-15', 'Pagado', 1),
(17, 17, 30333444, 400.00, 0.00, '2026-02-17', '2026-03-19', 'Pagado', 1),
(18, 18, 32200771, 650.00, 0.00, '2026-02-19', '2026-03-21', 'Pagado', 1),
(19, 19, 31039811, 625.00, 0.00, '2026-02-21', '2026-03-23', 'Pagado', 1),
(20, 20, 30666777, 490.00, 0.00, '2026-02-21', '2026-03-23', 'Pagado', 1),
(21, 21, 25566580, 840.00, 0.00, '2026-02-24', '2026-03-26', 'Pagado', 1),
(22, 22, 30666777, 360.00, 0.00, '2026-02-28', '2026-03-30', 'Pagado', 1),
(23, 23, 30222333, 400.00, 0.00, '2026-02-28', '2026-03-30', 'Pagado', 1),
(24, 24, 25566585, 400.00, 0.00, '2026-02-28', '2026-03-30', 'Pagado', 1),
(25, 25, 17100998, 475.00, 0.00, '2026-03-03', '2026-04-02', 'Pagado', 1),
(26, 26, 30111222, 910.00, 0.00, '2026-03-06', '2026-04-05', 'Pagado', 1),
(27, 27, 30444555, 195.00, 0.00, '2026-03-11', '2026-04-10', 'Pagado', 1),
(28, 28, 32200771, 315.00, 0.00, '2026-03-14', '2026-04-13', 'Pagado', 1),
(29, 29, 30333444, 390.00, 0.00, '2026-03-16', '2026-04-15', 'Pagado', 1),
(30, 30, 32200771, 470.80, 0.00, '2026-03-18', '2026-04-17', 'Pagado', 1),
(31, 31, 32200771, 840.00, 0.00, '2026-03-19', '2026-04-18', 'Pagado', 1),
(32, 32, 25566582, 555.00, 0.00, '2026-03-19', '2026-04-18', 'Pagado', 1),
(33, 33, 17100998, 240.00, 0.00, '2026-03-21', '2026-04-20', 'Pagado', 1),
(34, 34, 30333444, 405.00, 0.00, '2026-03-23', '2026-04-22', 'Pagado', 1),
(35, 35, 30666777, 400.00, 0.00, '2026-03-23', '2026-04-22', 'Pagado', 1),
(36, 36, 30111222, 595.00, 0.00, '2026-03-27', '2026-04-26', 'Pagado', 1),
(37, 37, 30444555, 710.00, 0.00, '2026-03-30', '2026-04-29', 'Pagado', 1),
(38, 38, 31039811, 466.00, 0.00, '2026-03-30', '2026-04-29', 'Pagado', 1),
(39, 39, 32200771, 675.00, 0.00, '2026-04-02', '2026-05-02', 'Pagado', 1),
(40, 40, 30555666, 585.00, 0.00, '2026-04-04', '2026-05-04', 'Pagado', 1),
(41, 41, 31039811, 740.00, 0.00, '2026-04-04', '2026-05-04', 'Pagado', 1),
(42, 42, 30333444, 770.00, 0.00, '2026-04-07', '2026-05-07', 'Pagado', 1),
(43, 43, 30222333, 670.00, 0.00, '2026-04-07', '2026-05-07', 'Pagado', 1),
(44, 44, 17100998, 455.00, 0.00, '2026-04-08', '2026-05-08', 'Pagado', 1),
(45, 45, 30333444, 455.00, 0.00, '2026-04-09', '2026-05-09', 'Pagado', 1),
(46, 46, 30111222, 300.00, 0.00, '2026-04-10', '2026-05-10', 'Pagado', 1),
(47, 47, 31039811, 630.00, 630.00, '2026-04-15', '2026-05-15', 'Por Pagar', 1),
(48, 48, 31039811, 450.00, 0.00, '2026-04-15', '2026-05-15', 'Pagado', 1),
(49, 49, 32200771, 195.00, 195.00, '2026-04-16', '2026-05-16', 'Por Pagar', 1),
(50, 50, 25566585, 195.00, 0.00, '2026-04-17', '2026-05-17', 'Pagado', 1),
(51, 51, 30333444, 610.00, 0.00, '2026-04-17', '2026-05-17', 'Pagado', 1),
(52, 52, 30333444, 505.00, 0.00, '2026-04-25', '2026-05-25', 'Pagado', 1),
(53, 53, 30333444, 550.00, 0.00, '2026-04-30', '2026-05-30', 'Pagado', 1),
(54, 54, 30666777, 630.00, 0.00, '2026-05-02', '2026-06-01', 'Pagado', 1),
(55, 55, 30333444, 227.50, 0.00, '2026-05-06', '2026-06-05', 'Pagado', 1),
(56, 56, 17100998, 475.00, 0.00, '2026-05-11', '2026-06-10', 'Pagado', 1),
(57, 57, 17100998, 487.50, 0.00, '2026-05-11', '2026-06-10', 'Pagado', 1),
(58, 58, 30444555, 542.50, 0.00, '2026-05-12', '2026-06-11', 'Pagado', 1),
(59, 59, 30333444, 575.00, 0.00, '2026-05-13', '2026-06-12', 'Pagado', 1),
(60, 60, 25566585, 540.00, 0.00, '2026-05-14', '2026-06-13', 'Pagado', 1),
(61, 61, 32200771, 280.00, 0.00, '2026-05-22', '2026-06-21', 'Pagado', 1),
(62, 62, 30666777, 560.00, 0.00, '2026-05-22', '2026-06-21', 'Pagado', 1),
(63, 63, 30333444, 580.00, 0.00, '2026-05-23', '2026-06-22', 'Pagado', 1),
(64, 64, 17100998, 875.00, 0.00, '2026-05-25', '2026-06-24', 'Pagado', 1),
(65, 65, 17100998, 350.00, 0.00, '2026-05-25', '2026-06-24', 'Pagado', 1),
(66, 66, 30666777, 340.00, 0.00, '2026-05-27', '2026-06-26', 'Pagado', 1),
(67, 67, 30222333, 320.00, 0.00, '2026-05-29', '2026-06-28', 'Pagado', 1),
(68, 68, 31039811, 675.00, 0.00, '2026-05-29', '2026-06-28', 'Pagado', 1),
(69, 69, 30444555, 495.00, 0.00, '2026-05-29', '2026-06-28', 'Pagado', 1),
(70, 70, 25566582, 550.00, 0.00, '2026-06-02', '2026-07-02', 'Pagado', 1),
(71, 71, 30666777, 650.00, 0.00, '2026-06-04', '2026-07-04', 'Pagado', 1),
(72, 72, 30444555, 515.00, 0.00, '2026-06-05', '2026-07-05', 'Pagado', 1),
(73, 73, 30444555, 450.00, 0.00, '2026-06-05', '2026-07-05', 'Pagado', 1),
(74, 74, 31039811, 695.00, 0.00, '2026-06-12', '2026-07-12', 'Pagado', 1),
(75, 75, 31039811, 280.00, 0.00, '2026-06-19', '2026-07-19', 'Pagado', 1),
(76, 76, 14555666, 375.00, 0.00, '2026-06-19', '2026-07-19', 'Pagado', 1),
(77, 77, 30666777, 375.00, 0.00, '2026-06-22', '2026-07-22', 'Pagado', 1),
(78, 78, 30333444, 700.00, 0.00, '2026-06-23', '2026-07-23', 'Pagado', 1),
(79, 79, 30222333, 195.00, 0.00, '2026-06-23', '2026-07-23', 'Pagado', 1),
(80, 80, 30111222, 390.00, 0.00, '2026-06-24', '2026-07-24', 'Pagado', 1),
(81, 81, 31039811, 635.00, 0.00, '2026-06-25', '2026-07-25', 'Pagado', 1),
(82, 82, 19888777, 180.00, 0.00, '2026-06-25', '2026-07-25', 'Pagado', 1),
(83, 83, 32200771, 435.00, 0.00, '2026-06-27', '2026-07-27', 'Pagado', 1),
(84, 84, 30666777, 650.00, 0.00, '2026-06-29', '2026-07-29', 'Pagado', 1),
(85, 85, 25566585, 700.00, 0.00, '2026-06-30', '2026-07-30', 'Pagado', 1),
(86, 86, 30666777, 700.00, 0.00, '2026-07-03', '2026-08-02', 'Pagado', 1),
(87, 87, 32200771, 700.00, 0.00, '2026-07-07', '2026-08-06', 'Pagado', 1),
(88, 88, 30333444, 450.00, 450.00, '2026-07-08', '2026-08-07', 'Por Pagar', 1),
(89, 89, 31039811, 360.00, 0.00, '2026-07-09', '2026-08-08', 'Pagado', 1),
(90, 90, 30555666, 280.00, 0.00, '2026-07-11', '2026-08-10', 'Pagado', 1),
(91, 91, 30222333, 700.00, 0.00, '2026-07-11', '2026-08-10', 'Pagado', 1),
(92, 92, 14555666, 460.00, 0.00, '2026-07-11', '2026-08-10', 'Pagado', 1),
(93, 93, 32200771, 250.00, 0.00, '2026-07-15', '2026-08-14', 'Pagado', 1),
(94, 94, 30222333, 500.00, 0.00, '2026-07-16', '2026-08-15', 'Pagado', 1),
(95, 95, 17100998, 585.00, 0.00, '2026-07-16', '2026-08-15', 'Pagado', 1),
(96, 96, 31039811, 330.00, 0.00, '2026-07-18', '2026-08-17', 'Pagado', 1),
(97, 97, 30333444, 540.00, 0.00, '2026-07-22', '2026-08-21', 'Pagado', 1),
(98, 98, 30333444, 560.00, 0.00, '2026-07-22', '2026-08-21', 'Pagado', 1),
(99, 99, 30333444, 625.00, 0.00, '2026-07-25', '2026-08-24', 'Pagado', 1),
(100, 100, 31039811, 455.00, 0.00, '2026-07-27', '2026-08-26', 'Pagado', 1),
(101, 101, 30333444, 200.00, 0.00, '2026-07-28', '2026-08-27', 'Pagado', 1),
(102, 102, 30444555, 450.00, 0.00, '2026-07-29', '2026-08-28', 'Pagado', 1),
(103, 103, 31039811, 515.00, 515.00, '2026-07-31', '2026-08-30', 'Por Pagar', 1),
(104, 104, 30333444, 420.00, 0.00, '2026-08-05', '2026-09-04', 'Pagado', 1),
(105, 105, 31039811, 500.00, 0.00, '2026-08-07', '2026-09-06', 'Pagado', 1),
(106, 106, 30666777, 375.00, 0.00, '2026-08-07', '2026-09-06', 'Pagado', 1),
(107, 107, 17100998, 360.00, 0.00, '2026-08-08', '2026-09-07', 'Pagado', 1),
(108, 108, 30555666, 735.00, 0.00, '2026-08-10', '2026-09-09', 'Pagado', 1),
(109, 109, 31039811, 555.00, 0.00, '2026-08-11', '2026-09-10', 'Pagado', 1),
(110, 110, 17100998, 390.00, 0.00, '2026-08-12', '2026-09-11', 'Pagado', 1),
(111, 111, 30333444, 300.00, 0.00, '2026-08-14', '2026-09-13', 'Pagado', 1),
(112, 112, 30555666, 565.00, 0.00, '2026-08-15', '2026-09-14', 'Pagado', 1),
(113, 113, 30333444, 420.00, 0.00, '2026-08-18', '2026-09-17', 'Pagado', 1),
(114, 114, 19888777, 520.00, 0.00, '2026-08-19', '2026-09-18', 'Pagado', 1),
(115, 115, 30111222, 240.00, 0.00, '2026-08-20', '2026-09-19', 'Pagado', 1),
(116, 116, 17100998, 805.00, 0.00, '2026-08-22', '2026-09-21', 'Pagado', 1),
(117, 117, 30111222, 745.00, 0.00, '2026-08-22', '2026-09-21', 'Pagado', 1),
(118, 118, 17100998, 610.00, 0.00, '2026-08-24', '2026-09-23', 'Pagado', 1),
(119, 119, 30333444, 840.00, 0.00, '2026-08-28', '2026-09-27', 'Pagado', 1),
(120, 120, 30333444, 490.00, 0.00, '2026-08-31', '2026-09-30', 'Pagado', 1),
(121, 121, 30444555, 430.00, 0.00, '2026-08-31', '2026-09-30', 'Pagado', 1),
(122, 122, 31039811, 470.00, 0.00, '2026-09-02', '2026-10-02', 'Pagado', 1),
(123, 123, 30666777, 275.00, 275.00, '2026-09-03', '2026-10-03', 'Por Pagar', 1),
(124, 124, 32200771, 315.00, 0.00, '2026-09-05', '2026-10-05', 'Pagado', 1),
(125, 125, 30222333, 455.00, 0.00, '2026-09-07', '2026-10-07', 'Pagado', 1),
(126, 126, 30666777, 575.00, 0.00, '2026-09-07', '2026-10-07', 'Pagado', 1),
(127, 127, 25566580, 595.00, 0.00, '2026-09-07', '2026-10-07', 'Pagado', 1),
(128, 128, 30333444, 735.00, 0.00, '2026-09-08', '2026-10-08', 'Pagado', 1),
(129, 129, 17100998, 600.00, 0.00, '2026-09-09', '2026-10-09', 'Pagado', 1),
(130, 130, 30555666, 735.00, 0.00, '2026-09-11', '2026-10-11', 'Pagado', 1),
(131, 131, 17100998, 455.00, 0.00, '2026-09-15', '2026-10-15', 'Pagado', 1),
(132, 132, 30444555, 375.00, 0.00, '2026-09-16', '2026-10-16', 'Pagado', 1),
(133, 133, 17100998, 400.00, 0.00, '2026-09-17', '2026-10-17', 'Pagado', 1),
(134, 134, 30666777, 405.00, 0.00, '2026-09-17', '2026-10-17', 'Pagado', 1),
(135, 135, 14555666, 541.00, 0.00, '2026-09-21', '2026-10-21', 'Pagado', 1),
(136, 136, 30111222, 500.00, 0.00, '2026-09-24', '2026-10-24', 'Pagado', 1),
(137, 137, 17100998, 425.00, 0.00, '2026-09-29', '2026-10-29', 'Pagado', 1),
(138, 138, 17100998, 325.00, 0.00, '2026-10-02', '2026-11-01', 'Pagado', 1),
(139, 139, 32200771, 675.00, 0.00, '2026-10-05', '2026-11-04', 'Pagado', 1),
(140, 140, 30222333, 280.00, 0.00, '2026-10-09', '2026-11-08', 'Pagado', 1),
(141, 141, 17100998, 225.00, 0.00, '2026-10-10', '2026-11-09', 'Pagado', 1),
(142, 142, 30111222, 165.00, 0.00, '2026-10-12', '2026-11-11', 'Pagado', 1),
(143, 143, 17100998, 382.50, 229.50, '2026-10-12', '2026-11-11', 'Por Pagar', 1),
(144, 144, 32200771, 425.00, 425.00, '2026-10-15', '2026-11-14', 'Por Pagar', 1),
(145, 145, 32200771, 525.00, 0.00, '2026-10-15', '2026-11-14', 'Pagado', 1),
(146, 146, 25566585, 400.00, 400.00, '2026-10-17', '2026-11-16', 'Por Pagar', 1),
(147, 147, 30444555, 675.00, 405.00, '2026-10-17', '2026-11-16', 'Por Pagar', 1),
(148, 148, 17100998, 275.00, 0.00, '2026-10-20', '2026-11-19', 'Pagado', 1),
(149, 149, 30111222, 340.00, 0.00, '2026-10-20', '2026-11-19', 'Pagado', 1),
(150, 150, 30666777, 460.00, 0.00, '2026-10-20', '2026-11-19', 'Pagado', 1),
(151, 151, 30666777, 385.00, 0.00, '2026-10-22', '2026-11-21', 'Pagado', 1),
(152, 152, 30111222, 630.00, 0.00, '2026-10-22', '2026-11-21', 'Pagado', 1),
(153, 153, 30222333, 325.00, 325.00, '2026-10-27', '2026-11-26', 'Por Pagar', 1),
(154, 154, 30444555, 250.00, 250.00, '2026-10-30', '2026-11-29', 'Por Pagar', 1),
(155, 155, 25566585, 300.00, 300.00, '2026-10-31', '2026-11-30', 'Por Pagar', 1),
(156, 156, 30555666, 535.00, 0.00, '2026-11-03', '2026-12-03', 'Pagado', 1),
(157, 157, 30333444, 650.00, 390.00, '2026-11-04', '2026-12-04', 'Por Pagar', 1),
(158, 158, 30333444, 437.50, 0.00, '2026-11-04', '2026-12-04', 'Pagado', 1),
(159, 159, 17100998, 365.00, 219.00, '2026-11-06', '2026-12-06', 'Por Pagar', 1),
(160, 160, 31039811, 430.00, 430.00, '2026-11-09', '2026-12-09', 'Por Pagar', 1),
(161, 161, 30333444, 650.00, 390.00, '2026-11-09', '2026-12-09', 'Por Pagar', 1),
(162, 162, 33220449, 545.00, 0.00, '2026-11-17', '2026-11-17', 'Pagado', 0);

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
(1, 1, 12321234, 1588.00, 0.00, '2026-01-02 00:00:00.000000', '2026-02-01 00:00:00.000000', 'Pagado', 1),
(2, 2, 17100998, 168.00, 0.00, '2026-01-02 00:00:00.000000', '2026-02-01 00:00:00.000000', 'Pagado', 1),
(3, 3, 31039711, 319.00, 0.00, '2026-01-02 00:00:00.000000', '2026-02-01 00:00:00.000000', 'Pagado', 1),
(4, 4, 12321234, 891.00, 0.00, '2026-02-02 00:00:00.000000', '2026-03-04 00:00:00.000000', 'Pagado', 1),
(5, 5, 17100998, 92.00, 0.00, '2026-02-02 00:00:00.000000', '2026-03-04 00:00:00.000000', 'Pagado', 1),
(6, 6, 31039711, 165.00, 0.00, '2026-02-02 00:00:00.000000', '2026-03-04 00:00:00.000000', 'Pagado', 1),
(7, 7, 12321234, 1098.00, 0.00, '2026-03-02 00:00:00.000000', '2026-04-01 00:00:00.000000', 'Pagado', 1),
(8, 8, 17100998, 116.00, 0.00, '2026-03-02 00:00:00.000000', '2026-04-01 00:00:00.000000', 'Pagado', 1),
(9, 9, 31039711, 220.00, 220.00, '2026-03-02 00:00:00.000000', '2026-04-01 00:00:00.000000', 'Por Pagar', 1),
(10, 10, 12321234, 964.00, 0.00, '2026-04-01 00:00:00.000000', '2026-05-01 00:00:00.000000', 'Pagado', 1),
(11, 11, 17100998, 104.00, 0.00, '2026-04-01 00:00:00.000000', '2026-05-01 00:00:00.000000', 'Pagado', 1),
(12, 12, 31039711, 209.00, 0.00, '2026-04-01 00:00:00.000000', '2026-05-01 00:00:00.000000', 'Pagado', 1),
(13, 13, 12321234, 1208.00, 0.00, '2026-05-01 00:00:00.000000', '2026-05-31 00:00:00.000000', 'Pagado', 1),
(14, 14, 17100998, 128.00, 0.00, '2026-05-01 00:00:00.000000', '2026-05-31 00:00:00.000000', 'Pagado', 1),
(15, 15, 31039711, 187.00, 0.00, '2026-05-01 00:00:00.000000', '2026-05-31 00:00:00.000000', 'Pagado', 1),
(16, 16, 12321234, 964.00, 0.00, '2026-06-01 00:00:00.000000', '2026-07-01 00:00:00.000000', 'Pagado', 1),
(17, 17, 17100998, 104.00, 0.00, '2026-06-01 00:00:00.000000', '2026-07-01 00:00:00.000000', 'Pagado', 1),
(18, 18, 31039711, 187.00, 0.00, '2026-06-01 00:00:00.000000', '2026-07-01 00:00:00.000000', 'Pagado', 1),
(19, 19, 12321234, 1330.00, 0.00, '2026-07-01 00:00:00.000000', '2026-07-31 00:00:00.000000', 'Pagado', 1),
(20, 20, 17100998, 140.00, 0.00, '2026-07-01 00:00:00.000000', '2026-07-31 00:00:00.000000', 'Pagado', 1),
(21, 21, 31039711, 220.00, 0.00, '2026-07-01 00:00:00.000000', '2026-07-31 00:00:00.000000', 'Pagado', 1),
(22, 22, 12321234, 1318.00, 0.00, '2026-08-01 00:00:00.000000', '2026-08-31 00:00:00.000000', 'Pagado', 1),
(23, 23, 17100998, 136.00, 0.00, '2026-08-01 00:00:00.000000', '2026-08-31 00:00:00.000000', 'Pagado', 1),
(24, 24, 31039711, 209.00, 0.00, '2026-08-01 00:00:00.000000', '2026-08-31 00:00:00.000000', 'Pagado', 1),
(25, 25, 12321234, 1147.00, 0.00, '2026-09-01 00:00:00.000000', '2026-10-01 00:00:00.000000', 'Pagado', 1),
(26, 26, 17100998, 120.00, 0.00, '2026-09-01 00:00:00.000000', '2026-10-01 00:00:00.000000', 'Pagado', 1),
(27, 27, 31039711, 209.00, 0.00, '2026-09-01 00:00:00.000000', '2026-10-01 00:00:00.000000', 'Pagado', 1),
(28, 28, 12321234, 964.00, 0.00, '2026-10-01 00:00:00.000000', '2026-10-31 00:00:00.000000', 'Pagado', 1),
(29, 29, 17100998, 104.00, 0.00, '2026-10-01 00:00:00.000000', '2026-10-31 00:00:00.000000', 'Pagado', 1),
(30, 30, 31039711, 154.00, 77.00, '2026-10-01 00:00:00.000000', '2026-10-31 00:00:00.000000', 'Por Pagar', 1),
(31, 31, 12321234, 586.00, 586.00, '2026-11-02 00:00:00.000000', '2026-12-02 00:00:00.000000', 'Por Pagar', 1),
(32, 32, 17100998, 60.00, 60.00, '2026-11-02 00:00:00.000000', '2026-12-02 00:00:00.000000', 'Por Pagar', 1),
(33, 33, 31039711, 121.00, 60.50, '2026-11-02 00:00:00.000000', '2026-12-02 00:00:00.000000', 'Por Pagar', 1);

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
(343, 1, 1, 30444555, '02510001104', 'Av Principal de Santa Rosa', 240),
(344, 2, 2, 17100998, '02511358621', 'Av Pedro leon con calle 54', 240),
(345, 3, 3, 17100998, '02511358621', 'Av Pedro leon con calle 54', 240),
(346, 4, 4, 25566585, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 260),
(347, 5, 5, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 280),
(348, 6, 6, 32200771, '02514408820', 'Calle 54 con Carrera 20', 220),
(349, 7, 7, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 220),
(350, 8, 8, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 260),
(351, 9, 9, 30444555, '02510001104', 'Av Principal de Santa Rosa', 260),
(352, 10, 10, 30555666, '04120001105', 'Plaza Bolivar, local 2', 250),
(353, 11, 11, 30555666, '04120001105', 'Plaza Bolivar, local 2', 270),
(354, 12, 12, 32200771, '02514408820', 'Calle 54 con Carrera 20', 240),
(355, 13, 13, 30555666, '04120001105', 'Plaza Bolivar, local 2', 140),
(356, 14, 14, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 230),
(357, 15, 15, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 260),
(358, 16, 16, 30444555, '02510001104', 'Av Principal de Santa Rosa', 270),
(359, 17, 17, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 200),
(360, 18, 18, 32200771, '02514408820', 'Calle 54 con Carrera 20', 260),
(361, 19, 19, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 250),
(362, 20, 20, 30666777, '02510001106', 'Av Venezuela con calle 12', 220),
(363, 21, 21, 25566580, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 240),
(364, 22, 22, 30666777, '02510001106', 'Av Venezuela con calle 12', 240),
(365, 23, 23, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 160),
(366, 24, 24, 25566585, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 230),
(367, 25, 25, 17100998, '02511358621', 'Av Pedro leon con calle 54', 190),
(368, 26, 26, 30111222, '04120001101', 'Carrera 19 con calle 30', 260),
(369, 27, 27, 30444555, '02510001104', 'Av Principal de Santa Rosa', 130),
(370, 28, 28, 32200771, '02514408820', 'Calle 54 con Carrera 20', 210),
(371, 29, 29, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 260),
(372, 30, 30, 32200771, '02514408820', 'Calle 54 con Carrera 20', 220),
(373, 31, 31, 32200771, '02514408820', 'Calle 54 con Carrera 20', 280),
(374, 32, 32, 25566582, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 250),
(375, 33, 33, 17100998, '02511358621', 'Av Pedro leon con calle 54', 160),
(376, 34, 34, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 270),
(377, 35, 35, 30666777, '02510001106', 'Av Venezuela con calle 12', 160),
(378, 36, 36, 30111222, '04120001101', 'Carrera 19 con calle 30', 250),
(379, 37, 37, 30444555, '02510001104', 'Av Principal de Santa Rosa', 240),
(380, 38, 38, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 250),
(381, 39, 39, 32200771, '02514408820', 'Calle 54 con Carrera 20', 270),
(382, 40, 40, 30555666, '04120001105', 'Plaza Bolivar, local 2', 230),
(383, 41, 41, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 240),
(384, 42, 42, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 260),
(385, 43, 43, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 220),
(386, 44, 44, 17100998, '02511358621', 'Av Pedro leon con calle 54', 130),
(387, 45, 45, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 130),
(388, 46, 46, 30111222, '04120001101', 'Carrera 19 con calle 30', 120),
(389, 47, 47, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 180),
(390, 48, 48, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 180),
(391, 49, 49, 32200771, '02514408820', 'Calle 54 con Carrera 20', 130),
(392, 50, 50, 25566585, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 130),
(393, 51, 51, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 270),
(394, 52, 52, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 250),
(395, 53, 53, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 220),
(396, 54, 54, 30666777, '02510001106', 'Av Venezuela con calle 12', 240),
(397, 55, 55, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 130),
(398, 56, 56, 17100998, '02511358621', 'Av Pedro leon con calle 54', 190),
(399, 57, 57, 17100998, '02511358621', 'Av Pedro leon con calle 54', 260),
(400, 58, 58, 30444555, '02510001104', 'Av Principal de Santa Rosa', 250),
(401, 59, 59, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 230),
(402, 60, 60, 25566585, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 270),
(403, 61, 61, 32200771, '02514408820', 'Calle 54 con Carrera 20', 140),
(404, 62, 62, 30666777, '02510001106', 'Av Venezuela con calle 12', 240),
(405, 63, 63, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 260),
(406, 64, 64, 17100998, '02511358621', 'Av Pedro leon con calle 54', 250),
(407, 65, 65, 17100998, '02511358621', 'Av Pedro leon con calle 54', 140),
(408, 66, 66, 30666777, '02510001106', 'Av Venezuela con calle 12', 170),
(409, 67, 67, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 160),
(410, 68, 68, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 270),
(411, 69, 69, 30444555, '02510001104', 'Av Principal de Santa Rosa', 220),
(412, 70, 70, 25566582, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 240),
(413, 71, 71, 30666777, '02510001106', 'Av Venezuela con calle 12', 260),
(414, 72, 72, 30444555, '02510001104', 'Av Principal de Santa Rosa', 210),
(415, 73, 73, 30444555, '02510001104', 'Av Principal de Santa Rosa', 180),
(416, 74, 74, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 230),
(417, 75, 75, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 140),
(418, 76, 76, 14555666, '04120001107', 'Urb Del Este, calle 5', 250),
(419, 77, 77, 30666777, '02510001106', 'Av Venezuela con calle 12', 150),
(420, 78, 78, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 200),
(421, 79, 79, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 130),
(422, 80, 80, 30111222, '04120001101', 'Carrera 19 con calle 30', 220),
(423, 81, 81, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 210),
(424, 82, 82, 19888777, '04120001108', 'Barrio El Jebe, calle 3', 120),
(425, 83, 83, 32200771, '02514408820', 'Calle 54 con Carrera 20', 250),
(426, 84, 84, 30666777, '02510001106', 'Av Venezuela con calle 12', 260),
(427, 85, 85, 25566585, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 280),
(428, 86, 86, 30666777, '02510001106', 'Av Venezuela con calle 12', 280),
(429, 87, 87, 32200771, '02514408820', 'Calle 54 con Carrera 20', 280),
(430, 88, 88, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 180),
(431, 89, 89, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 180),
(432, 90, 90, 30555666, '04120001105', 'Plaza Bolivar, local 2', 140),
(433, 91, 91, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 200),
(434, 92, 92, 14555666, '04120001107', 'Urb Del Este, calle 5', 260),
(435, 93, 93, 32200771, '02514408820', 'Calle 54 con Carrera 20', 100),
(436, 94, 94, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 200),
(437, 95, 95, 17100998, '02511358621', 'Av Pedro leon con calle 54', 260),
(438, 96, 96, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 220),
(439, 97, 97, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 270),
(440, 98, 98, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 280),
(441, 99, 99, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 250),
(442, 100, 100, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 130),
(443, 101, 101, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 100),
(444, 102, 102, 30444555, '02510001104', 'Av Principal de Santa Rosa', 180),
(445, 103, 103, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 210),
(446, 104, 104, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 210),
(447, 105, 105, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 250),
(448, 106, 106, 30666777, '02510001106', 'Av Venezuela con calle 12', 250),
(449, 107, 107, 17100998, '02511358621', 'Av Pedro leon con calle 54', 180),
(450, 108, 108, 30555666, '04120001105', 'Plaza Bolivar, local 2', 210),
(451, 109, 109, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 250),
(452, 110, 110, 17100998, '02511358621', 'Av Pedro leon con calle 54', 260),
(453, 111, 111, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 120),
(454, 112, 112, 30555666, '04120001105', 'Plaza Bolivar, local 2', 250),
(455, 113, 113, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 120),
(456, 114, 114, 19888777, '04120001108', 'Barrio El Jebe, calle 3', 260),
(457, 115, 115, 30111222, '04120001101', 'Carrera 19 con calle 30', 160),
(458, 116, 116, 17100998, '02511358621', 'Av Pedro leon con calle 54', 230),
(459, 117, 117, 30111222, '04120001101', 'Carrera 19 con calle 30', 250),
(460, 118, 118, 17100998, '02511358621', 'Av Pedro leon con calle 54', 270),
(461, 119, 119, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 280),
(462, 120, 120, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 140),
(463, 121, 121, 30444555, '02510001104', 'Av Principal de Santa Rosa', 220),
(464, 122, 122, 31039811, '02513213495', 'Av Urb Patarata con Calle 20', 240),
(465, 123, 123, 30666777, '02510001106', 'Av Venezuela con calle 12', 110),
(466, 124, 124, 32200771, '02514408820', 'Calle 54 con Carrera 20', 210),
(467, 125, 125, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 210),
(468, 126, 126, 30666777, '02510001106', 'Av Venezuela con calle 12', 230),
(469, 127, 127, 25566580, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 170),
(470, 128, 128, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 210),
(471, 129, 129, 17100998, '02511358621', 'Av Pedro leon con calle 54', 240),
(472, 130, 130, 30555666, '04120001105', 'Plaza Bolivar, local 2', 270),
(473, 131, 131, 17100998, '02511358621', 'Av Pedro leon con calle 54', 130),
(474, 132, 132, 30444555, '02510001104', 'Av Principal de Santa Rosa', 150),
(475, 133, 133, 17100998, '02511358621', 'Av Pedro leon con calle 54', 160),
(476, 134, 134, 30666777, '02510001106', 'Av Venezuela con calle 12', 270),
(477, 135, 135, 14555666, '04120001107', 'Urb Del Este, calle 5', 250),
(478, 136, 136, 30111222, '04120001101', 'Carrera 19 con calle 30', 250),
(479, 137, 137, 17100998, '02511358621', 'Av Pedro leon con calle 54', 170),
(480, 138, 138, 17100998, '02511358621', 'Av Pedro leon con calle 54', 130),
(481, 139, 139, 32200771, '02514408820', 'Calle 54 con Carrera 20', 270),
(482, 140, 140, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 140),
(483, 141, 141, 17100998, '02511358621', 'Av Pedro leon con calle 54', 150),
(484, 142, 142, 30111222, '04120001101', 'Carrera 19 con calle 30', 110),
(485, 143, 143, 17100998, '02511358621', 'Av Pedro leon con calle 54', 230),
(486, 144, 144, 32200771, '02514408820', 'Calle 54 con Carrera 20', 170),
(487, 145, 145, 32200771, '02514408820', 'Calle 54 con Carrera 20', 230),
(488, 146, 146, 25566585, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 160),
(489, 147, 147, 30444555, '02510001104', 'Av Principal de Santa Rosa', 270),
(490, 148, 148, 17100998, '02511358621', 'Av Pedro leon con calle 54', 110),
(491, 149, 149, 30111222, '04120001101', 'Carrera 19 con calle 30', 170),
(492, 150, 150, 30666777, '02510001106', 'Av Venezuela con calle 12', 230),
(493, 151, 151, 30666777, '02510001106', 'Av Venezuela con calle 12', 280),
(494, 152, 152, 30111222, '04120001101', 'Carrera 19 con calle 30', 240),
(495, 153, 153, 30222333, '04120001102', 'Calle 42 entre carreras 25 y 26', 130),
(496, 154, 154, 30444555, '02510001104', 'Av Principal de Santa Rosa', 100),
(497, 155, 155, 25566585, '04122373562', 'Urb Eligio Macias Mujica Calle 3', 150),
(498, 156, 156, 30555666, '04120001105', 'Plaza Bolivar, local 2', 270),
(499, 157, 157, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 260),
(500, 158, 158, 30333444, '02510001103', 'Zona Industrial I, galpon 8', 250);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_carrito`
--

CREATE TABLE `detalle_carrito` (
  `id_detalle_carrito` int(11) NOT NULL,
  `id_carrito` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_unitario` float(11,2) NOT NULL,
  `fecha_agregado` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `detalle_carrito`
--

INSERT INTO `detalle_carrito` (`id_detalle_carrito`, `id_carrito`, `id_producto`, `cantidad`, `precio_unitario`, `fecha_agregado`) VALUES
(1, 1, 2, 130, 3.50, '2026-11-17 16:37:31'),
(2, 1, 4, 100, 2.50, '2026-11-17 16:37:32');

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
(141, 1, 1, 740, 1.20),
(142, 1, 4, 280, 2.50),
(143, 2, 2, 420, 0.40),
(144, 3, 3, 290, 1.10),
(145, 4, 1, 430, 1.20),
(146, 4, 4, 150, 2.50),
(147, 5, 2, 230, 0.40),
(148, 6, 3, 150, 1.10),
(149, 7, 1, 540, 1.20),
(150, 7, 4, 180, 2.50),
(151, 8, 2, 290, 0.40),
(152, 9, 3, 200, 1.10),
(153, 10, 1, 470, 1.20),
(154, 10, 4, 160, 2.50),
(155, 11, 2, 260, 0.40),
(156, 12, 3, 190, 1.10),
(157, 13, 1, 590, 1.20),
(158, 13, 4, 200, 2.50),
(159, 14, 2, 320, 0.40),
(160, 15, 3, 170, 1.10),
(161, 16, 1, 470, 1.20),
(162, 16, 4, 160, 2.50),
(163, 17, 2, 260, 0.40),
(164, 18, 3, 170, 1.10),
(165, 19, 1, 650, 1.20),
(166, 19, 4, 220, 2.50),
(167, 20, 2, 350, 0.40),
(168, 21, 3, 200, 1.10),
(169, 22, 1, 640, 1.20),
(170, 22, 4, 220, 2.50),
(171, 23, 2, 340, 0.40),
(172, 24, 3, 190, 1.10),
(173, 25, 1, 560, 1.20),
(174, 25, 4, 190, 2.50),
(175, 26, 2, 300, 0.40),
(176, 27, 3, 190, 1.10),
(177, 28, 1, 470, 1.20),
(178, 28, 4, 160, 2.50),
(179, 29, 2, 260, 0.40),
(180, 30, 3, 140, 1.10),
(181, 31, 1, 280, 1.20),
(182, 31, 4, 100, 2.50),
(183, 32, 2, 150, 0.40),
(184, 33, 3, 110, 1.10);

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
(574, 1, 4, 100, 2.50),
(575, 1, 2, 140, 3.50),
(576, 2, 1, 240, 1.50),
(577, 3, 4, 110, 2.50),
(578, 3, 3, 130, 2.00),
(579, 4, 4, 260, 2.50),
(580, 5, 3, 140, 2.00),
(581, 5, 1, 140, 1.50),
(582, 6, 5, 100, 2.50),
(583, 6, 3, 120, 2.00),
(584, 7, 1, 220, 1.50),
(585, 8, 4, 260, 2.50),
(586, 9, 4, 140, 2.50),
(587, 9, 5, 120, 2.50),
(588, 10, 4, 140, 2.50),
(589, 10, 1, 110, 1.50),
(590, 11, 5, 140, 2.50),
(591, 11, 1, 130, 1.50),
(592, 12, 1, 240, 1.50),
(593, 13, 1, 140, 1.50),
(594, 14, 4, 120, 2.50),
(595, 14, 5, 110, 2.50),
(596, 15, 4, 260, 2.50),
(597, 16, 4, 270, 2.50),
(598, 17, 3, 200, 2.00),
(599, 18, 4, 260, 2.50),
(600, 19, 4, 250, 2.50),
(601, 20, 3, 120, 2.00),
(602, 20, 4, 100, 2.50),
(603, 21, 2, 240, 3.50),
(604, 22, 1, 240, 1.50),
(605, 23, 5, 160, 2.50),
(606, 24, 1, 120, 1.50),
(607, 24, 3, 110, 2.00),
(608, 25, 5, 190, 2.50),
(609, 26, 2, 260, 3.50),
(610, 27, 1, 130, 1.50),
(611, 28, 1, 210, 1.50),
(612, 29, 1, 260, 1.50),
(613, 30, 3, 120, 2.00),
(614, 30, 4, 100, 2.50),
(615, 31, 2, 140, 3.50),
(616, 31, 5, 140, 2.50),
(617, 32, 3, 140, 2.00),
(618, 32, 4, 110, 2.50),
(619, 33, 1, 160, 1.50),
(620, 34, 1, 270, 1.50),
(621, 35, 4, 160, 2.50),
(622, 36, 1, 140, 1.50),
(623, 36, 2, 110, 3.50),
(624, 37, 2, 110, 3.50),
(625, 37, 5, 130, 2.50),
(626, 38, 4, 130, 2.50),
(627, 38, 1, 120, 1.50),
(628, 39, 4, 270, 2.50),
(629, 40, 2, 120, 3.50),
(630, 40, 1, 110, 1.50),
(631, 41, 5, 100, 2.50),
(632, 41, 2, 140, 3.50),
(633, 42, 5, 140, 2.50),
(634, 42, 2, 120, 3.50),
(635, 43, 5, 100, 2.50),
(636, 43, 2, 120, 3.50),
(637, 44, 2, 130, 3.50),
(638, 45, 2, 130, 3.50),
(639, 46, 5, 120, 2.50),
(640, 47, 2, 180, 3.50),
(641, 48, 4, 180, 2.50),
(642, 49, 1, 130, 1.50),
(643, 50, 1, 130, 1.50),
(644, 51, 3, 130, 2.00),
(645, 51, 5, 140, 2.50),
(646, 52, 5, 130, 2.50),
(647, 52, 1, 120, 1.50),
(648, 53, 4, 100, 2.50),
(649, 53, 5, 120, 2.50),
(650, 54, 3, 140, 2.00),
(651, 54, 2, 100, 3.50),
(652, 55, 2, 130, 3.50),
(653, 56, 5, 190, 2.50),
(654, 57, 2, 130, 3.50),
(655, 57, 3, 130, 2.00),
(656, 58, 2, 110, 3.50),
(657, 58, 5, 140, 2.50),
(658, 59, 5, 120, 2.50),
(659, 59, 4, 110, 2.50),
(660, 60, 3, 270, 2.00),
(661, 61, 3, 140, 2.00),
(662, 62, 1, 140, 1.50),
(663, 62, 2, 100, 3.50),
(664, 63, 3, 140, 2.00),
(665, 63, 5, 120, 2.50),
(666, 64, 2, 250, 3.50),
(667, 65, 5, 140, 2.50),
(668, 66, 3, 170, 2.00),
(669, 67, 3, 160, 2.00),
(670, 68, 4, 270, 2.50),
(671, 69, 5, 110, 2.50),
(672, 69, 3, 110, 2.00),
(673, 70, 5, 140, 2.50),
(674, 70, 3, 100, 2.00),
(675, 71, 5, 260, 2.50),
(676, 72, 2, 100, 3.50),
(677, 72, 1, 110, 1.50),
(678, 73, 5, 180, 2.50),
(679, 74, 5, 110, 2.50),
(680, 74, 2, 120, 3.50),
(681, 75, 3, 140, 2.00),
(682, 76, 1, 250, 1.50),
(683, 77, 5, 150, 2.50),
(684, 78, 2, 200, 3.50),
(685, 79, 1, 130, 1.50),
(686, 80, 1, 100, 1.50),
(687, 80, 3, 120, 2.00),
(688, 81, 2, 110, 3.50),
(689, 81, 5, 100, 2.50),
(690, 82, 1, 120, 1.50),
(691, 83, 3, 120, 2.00),
(692, 83, 1, 130, 1.50),
(693, 84, 5, 260, 2.50),
(694, 85, 4, 280, 2.50),
(695, 86, 4, 280, 2.50),
(696, 87, 4, 280, 2.50),
(697, 88, 4, 180, 2.50),
(698, 89, 3, 180, 2.00),
(699, 90, 3, 140, 2.00),
(700, 91, 2, 200, 3.50),
(701, 92, 1, 120, 1.50),
(702, 92, 3, 140, 2.00),
(703, 93, 4, 100, 2.50),
(704, 94, 4, 200, 2.50),
(705, 95, 5, 260, 2.50),
(706, 96, 1, 220, 1.50),
(707, 97, 3, 270, 2.00),
(708, 98, 3, 280, 2.00),
(709, 99, 4, 250, 2.50),
(710, 100, 2, 130, 3.50),
(711, 101, 3, 100, 2.00),
(712, 102, 5, 180, 2.50),
(713, 103, 2, 100, 3.50),
(714, 103, 1, 110, 1.50),
(715, 104, 3, 210, 2.00),
(716, 105, 3, 250, 2.00),
(717, 106, 1, 250, 1.50),
(718, 107, 3, 180, 2.00),
(719, 108, 2, 210, 3.50),
(720, 109, 4, 110, 2.50),
(721, 109, 3, 140, 2.00),
(722, 110, 1, 260, 1.50),
(723, 111, 4, 120, 2.50),
(724, 112, 5, 130, 2.50),
(725, 112, 3, 120, 2.00),
(726, 113, 2, 120, 3.50),
(727, 114, 3, 260, 2.00),
(728, 115, 1, 160, 1.50),
(729, 116, 2, 230, 3.50),
(730, 117, 2, 120, 3.50),
(731, 117, 5, 130, 2.50),
(732, 118, 3, 130, 2.00),
(733, 118, 5, 140, 2.50),
(734, 119, 2, 140, 3.50),
(735, 119, 5, 140, 2.50),
(736, 120, 2, 140, 3.50),
(737, 121, 5, 100, 2.50),
(738, 121, 1, 120, 1.50),
(739, 122, 1, 130, 1.50),
(740, 122, 4, 110, 2.50),
(741, 123, 5, 110, 2.50),
(742, 124, 1, 210, 1.50),
(743, 125, 3, 100, 2.00),
(744, 125, 5, 110, 2.50),
(745, 126, 4, 230, 2.50),
(746, 127, 2, 170, 3.50),
(747, 128, 2, 210, 3.50),
(748, 129, 4, 240, 2.50),
(749, 130, 2, 130, 3.50),
(750, 130, 3, 140, 2.00),
(751, 131, 2, 130, 3.50),
(752, 132, 5, 150, 2.50),
(753, 133, 4, 160, 2.50),
(754, 134, 1, 270, 1.50),
(755, 135, 3, 120, 2.00),
(756, 135, 5, 130, 2.50),
(757, 136, 3, 250, 2.00),
(758, 137, 5, 170, 2.50),
(759, 138, 5, 130, 2.50),
(760, 139, 5, 140, 2.50),
(761, 139, 4, 130, 2.50),
(762, 140, 3, 140, 2.00),
(763, 141, 1, 150, 1.50),
(764, 142, 1, 110, 1.50),
(765, 143, 5, 120, 2.50),
(766, 143, 1, 110, 1.50),
(767, 144, 4, 170, 2.50),
(768, 145, 3, 100, 2.00),
(769, 145, 4, 130, 2.50),
(770, 146, 4, 160, 2.50),
(771, 147, 4, 130, 2.50),
(772, 147, 5, 140, 2.50),
(773, 148, 4, 110, 2.50),
(774, 149, 3, 170, 2.00),
(775, 150, 3, 230, 2.00),
(776, 151, 1, 140, 1.50),
(777, 151, 3, 140, 2.00),
(778, 152, 3, 140, 2.00),
(779, 152, 2, 100, 3.50),
(780, 153, 4, 130, 2.50),
(781, 154, 4, 100, 2.50),
(782, 155, 3, 150, 2.00),
(783, 156, 5, 130, 2.50),
(784, 156, 1, 140, 1.50),
(785, 157, 4, 260, 2.50),
(786, 158, 2, 250, 3.50),
(787, 159, 1, 110, 1.50),
(788, 159, 3, 100, 2.00),
(789, 160, 1, 120, 1.50),
(790, 160, 4, 100, 2.50),
(791, 161, 5, 260, 2.50),
(792, 162, 1, 130, 1.50),
(793, 162, 2, 100, 3.50);

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
(489, 1, 1, 195),
(490, 1, 2, 104),
(491, 1, 3, 78),
(492, 1, 4, 65),
(493, 2, 1, 75),
(494, 2, 2, 40),
(495, 2, 3, 30),
(496, 2, 4, 25),
(497, 3, 1, 90),
(498, 3, 2, 48),
(499, 3, 3, 6),
(500, 3, 4, 30),
(501, 4, 1, 195),
(502, 4, 2, 104),
(503, 4, 3, 78),
(504, 4, 4, 65),
(505, 5, 1, 90),
(506, 5, 2, 48),
(507, 5, 3, 36),
(508, 5, 4, 30),
(509, 6, 1, 90),
(510, 6, 2, 48),
(511, 6, 3, 36),
(512, 6, 4, 30),
(513, 7, 1, 30),
(514, 7, 2, 16),
(515, 7, 3, 12),
(516, 7, 4, 10),
(517, 8, 1, 60),
(518, 8, 2, 32),
(519, 8, 3, 4),
(520, 8, 4, 20),
(521, 9, 1, 180),
(522, 9, 2, 96),
(523, 9, 3, 72),
(524, 9, 4, 60),
(525, 10, 1, 30),
(526, 10, 2, 16),
(527, 10, 3, 12),
(528, 10, 4, 10),
(529, 11, 1, 180),
(530, 11, 2, 96),
(531, 11, 3, 72),
(532, 11, 4, 60),
(533, 12, 1, 90),
(534, 12, 2, 48),
(535, 12, 3, 36),
(536, 12, 4, 30),
(537, 13, 1, 60),
(538, 13, 2, 32),
(539, 13, 3, 4),
(540, 13, 4, 20),
(541, 14, 1, 75),
(542, 14, 2, 40),
(543, 14, 3, 30),
(544, 14, 4, 25),
(545, 15, 1, 90),
(546, 15, 2, 48),
(547, 15, 3, 36),
(548, 15, 4, 30),
(549, 16, 1, 75),
(550, 16, 2, 40),
(551, 16, 3, 30),
(552, 16, 4, 25),
(553, 17, 1, 135),
(554, 17, 2, 72),
(555, 17, 3, 54),
(556, 17, 4, 45),
(557, 18, 1, 15),
(558, 18, 2, 8),
(559, 18, 3, 1),
(560, 18, 4, 5),
(561, 19, 1, 90),
(562, 19, 2, 48),
(563, 19, 3, 36),
(564, 19, 4, 30),
(565, 20, 1, 120),
(566, 20, 2, 64),
(567, 20, 3, 48),
(568, 20, 4, 40),
(569, 21, 1, 30),
(570, 21, 2, 16),
(571, 21, 3, 12),
(572, 21, 4, 10),
(573, 22, 1, 135),
(574, 22, 2, 72),
(575, 22, 3, 54),
(576, 22, 4, 45),
(577, 23, 1, 195),
(578, 23, 2, 104),
(579, 23, 3, 13),
(580, 23, 4, 65),
(581, 24, 1, 45),
(582, 24, 2, 24),
(583, 24, 3, 18),
(584, 24, 4, 15),
(585, 25, 1, 135),
(586, 25, 2, 72),
(587, 25, 3, 54),
(588, 25, 4, 45),
(589, 26, 1, 105),
(590, 26, 2, 56),
(591, 26, 3, 42),
(592, 26, 4, 35),
(593, 27, 1, 60),
(594, 27, 2, 32),
(595, 27, 3, 24),
(596, 27, 4, 20),
(597, 28, 1, 60),
(598, 28, 2, 32),
(599, 28, 3, 4),
(600, 28, 4, 20),
(601, 29, 1, 45),
(602, 29, 2, 24),
(603, 29, 3, 18),
(604, 29, 4, 15),
(605, 30, 1, 165),
(606, 30, 2, 88),
(607, 30, 3, 66),
(608, 30, 4, 55),
(609, 31, 1, 75),
(610, 31, 2, 40),
(611, 31, 3, 30),
(612, 31, 4, 25),
(613, 32, 1, 90),
(614, 32, 2, 48),
(615, 32, 3, 36),
(616, 32, 4, 30),
(617, 33, 1, 165),
(618, 33, 2, 88),
(619, 33, 3, 11),
(620, 33, 4, 55),
(621, 34, 1, 210),
(622, 34, 2, 112),
(623, 34, 3, 84),
(624, 34, 4, 70),
(625, 35, 1, 60),
(626, 35, 2, 32),
(627, 35, 3, 24),
(628, 35, 4, 20),
(629, 36, 1, 135),
(630, 36, 2, 72),
(631, 36, 3, 54),
(632, 36, 4, 45),
(633, 37, 1, 120),
(634, 37, 2, 64),
(635, 37, 3, 48),
(636, 37, 4, 40),
(637, 38, 1, 195),
(638, 38, 2, 104),
(639, 38, 3, 13),
(640, 38, 4, 65),
(641, 39, 1, 15),
(642, 39, 2, 8),
(643, 39, 3, 6),
(644, 39, 4, 5),
(645, 40, 1, 120),
(646, 40, 2, 64),
(647, 40, 3, 48),
(648, 40, 4, 40),
(649, 41, 1, 75),
(650, 41, 2, 40),
(651, 41, 3, 30),
(652, 41, 4, 25),
(653, 42, 1, 120),
(654, 42, 2, 64),
(655, 42, 3, 48),
(656, 42, 4, 40),
(657, 43, 1, 105),
(658, 43, 2, 56),
(659, 43, 3, 7),
(660, 43, 4, 35),
(661, 44, 1, 120),
(662, 44, 2, 64),
(663, 44, 3, 48),
(664, 44, 4, 40),
(665, 45, 1, 90),
(666, 45, 2, 48),
(667, 45, 3, 36),
(668, 45, 4, 30),
(669, 46, 1, 75),
(670, 46, 2, 40),
(671, 46, 3, 30),
(672, 46, 4, 25),
(673, 47, 1, 150),
(674, 47, 2, 80),
(675, 47, 3, 10),
(676, 47, 4, 50),
(677, 48, 1, 150),
(678, 48, 2, 80),
(679, 48, 3, 60),
(680, 48, 4, 50),
(681, 49, 1, 60),
(682, 49, 2, 32),
(683, 49, 3, 24),
(684, 49, 4, 20),
(685, 50, 1, 75),
(686, 50, 2, 40),
(687, 50, 3, 30),
(688, 50, 4, 25),
(689, 51, 1, 30),
(690, 51, 2, 16),
(691, 51, 3, 12),
(692, 51, 4, 10),
(693, 52, 1, 15),
(694, 52, 2, 8),
(695, 52, 3, 1),
(696, 52, 4, 5),
(697, 53, 1, 60),
(698, 53, 2, 32),
(699, 53, 3, 24),
(700, 53, 4, 20),
(701, 54, 1, 75),
(702, 54, 2, 40),
(703, 54, 3, 30),
(704, 54, 4, 25);

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
(75, 1, 1),
(76, 2, 2),
(77, 3, 3),
(78, 4, 4),
(79, 5, 2),
(80, 6, 5),
(81, 7, 3),
(82, 8, 1),
(83, 9, 2),
(84, 10, 4);

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
  `id_camion` int(11) DEFAULT NULL,
  `observaciones` varchar(300) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `id_pedido` int(11) NOT NULL,
  `id_estado` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `entregas`
--

INSERT INTO `entregas` (`id_entregas`, `fecha_entrega_programada`, `fecha_entrega_real`, `id_estado_entrega`, `repartidor`, `id_camion`, `observaciones`, `status`, `id_pedido`, `id_estado`) VALUES
(1, '2026-01-08', '2026-01-08', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 1, 0),
(2, '2026-01-09', '2026-01-09', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 2, 0),
(3, '2026-01-11', '2026-01-11', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 3, 0),
(4, '2026-01-19', '2026-01-19', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 4, 0),
(5, '2026-01-19', '2026-01-19', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 5, 0),
(6, '2026-01-22', '2026-01-22', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 6, 0),
(7, '2026-01-20', '2026-01-20', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 7, 0),
(8, '2026-01-24', '2026-01-24', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 8, 0),
(9, '2026-01-27', '2026-01-27', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 9, 0),
(10, '2026-01-29', '2026-01-29', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 10, 0),
(11, '2026-01-29', '2026-01-29', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 11, 0),
(12, '2026-01-30', '2026-01-30', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 12, 0),
(13, '2026-02-10', '2026-02-10', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 13, 0),
(14, '2026-02-12', '2026-02-12', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 14, 0),
(15, '2026-02-15', '2026-02-15', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 15, 0),
(16, '2026-02-15', '2026-02-15', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 16, 0),
(17, '2026-02-18', '2026-02-18', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 17, 0),
(18, '2026-02-21', '2026-02-21', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 18, 0),
(19, '2026-02-24', '2026-02-24', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 19, 0),
(20, '2026-02-22', '2026-02-22', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 20, 0),
(21, '2026-02-25', '2026-02-25', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 21, 0),
(22, '2026-03-01', '2026-03-01', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 22, 0),
(23, '2026-03-01', '2026-03-01', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 23, 0),
(24, '2026-03-02', '2026-03-02', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 24, 0),
(25, '2026-03-05', '2026-03-05', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 25, 0),
(26, '2026-03-08', '2026-03-08', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 26, 0),
(27, '2026-03-12', '2026-03-12', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 27, 0),
(28, '2026-03-15', '2026-03-15', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 28, 0),
(29, '2026-03-19', '2026-03-19', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 29, 0),
(30, '2026-03-21', '2026-03-21', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 30, 0),
(31, '2026-03-21', '2026-03-21', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 31, 0),
(32, '2026-03-21', '2026-03-21', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 32, 0),
(33, '2026-03-24', '2026-03-24', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 33, 0),
(34, '2026-03-26', '2026-03-26', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 34, 0),
(35, '2026-03-26', '2026-03-26', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 35, 0),
(36, '2026-03-30', '2026-03-30', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 36, 0),
(37, '2026-04-01', '2026-04-01', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 37, 0),
(38, '2026-04-02', '2026-04-02', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 38, 0),
(39, '2026-04-04', '2026-04-04', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 39, 0),
(40, '2026-04-05', '2026-04-05', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 40, 0),
(41, '2026-04-07', '2026-04-07', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 41, 0),
(42, '2026-04-08', '2026-04-08', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 42, 0),
(43, '2026-04-10', '2026-04-10', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 43, 0),
(44, '2026-04-10', '2026-04-10', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 44, 0),
(45, '2026-04-11', '2026-04-11', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 45, 0),
(46, '2026-04-11', '2026-04-11', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 46, 0),
(47, '2026-04-17', '2026-04-17', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 47, 0),
(48, '2026-04-16', '2026-04-16', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 48, 0),
(49, '2026-04-17', '2026-04-17', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 49, 0),
(50, '2026-04-18', '2026-04-18', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 50, 0),
(51, '2026-04-18', '2026-04-18', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 51, 0),
(52, '2026-04-28', '2026-04-28', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 52, 0),
(53, '2026-05-01', '2026-05-01', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 53, 0),
(54, '2026-05-05', '2026-05-05', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 54, 0),
(55, '2026-05-09', '2026-05-09', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 55, 0),
(56, '2026-05-13', '2026-05-13', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 56, 0),
(57, '2026-05-13', '2026-05-13', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 57, 0),
(58, '2026-05-15', '2026-05-15', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 58, 0),
(59, '2026-05-16', '2026-05-16', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 59, 0),
(60, '2026-05-17', '2026-05-17', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 60, 0),
(61, '2026-05-24', '2026-05-24', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 61, 0),
(62, '2026-05-25', '2026-05-25', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 62, 0),
(63, '2026-05-26', '2026-05-26', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 63, 0),
(64, '2026-05-26', '2026-05-26', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 64, 0),
(65, '2026-05-28', '2026-05-28', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 65, 0),
(66, '2026-05-30', '2026-05-30', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 66, 0),
(67, '2026-05-31', '2026-05-31', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 67, 0),
(68, '2026-05-30', '2026-05-30', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 68, 0),
(69, '2026-05-31', '2026-05-31', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 69, 0),
(70, '2026-06-03', '2026-06-03', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 70, 0),
(71, '2026-06-05', '2026-06-05', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 71, 0),
(72, '2026-06-08', '2026-06-08', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 72, 0),
(73, '2026-06-08', '2026-06-08', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 73, 0),
(74, '2026-06-13', '2026-06-13', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 74, 0),
(75, '2026-06-21', '2026-06-21', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 75, 0),
(76, '2026-06-21', '2026-06-21', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 76, 0),
(77, '2026-06-25', '2026-06-25', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 77, 0),
(78, '2026-06-24', '2026-06-24', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 78, 0),
(79, '2026-06-25', '2026-06-25', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 79, 0),
(80, '2026-06-26', '2026-06-26', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 80, 0),
(81, '2026-06-28', '2026-06-28', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 81, 0),
(82, '2026-06-26', '2026-06-26', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 82, 0),
(83, '2026-06-28', '2026-06-28', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 83, 0),
(84, '2026-06-30', '2026-06-30', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 84, 0),
(85, '2026-07-01', '2026-07-01', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 85, 0),
(86, '2026-07-04', '2026-07-04', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 86, 0),
(87, '2026-07-08', '2026-07-08', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 87, 0),
(88, '2026-07-09', '2026-07-09', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 88, 0),
(89, '2026-07-10', '2026-07-10', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 89, 0),
(90, '2026-07-12', '2026-07-12', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 90, 0),
(91, '2026-07-13', '2026-07-13', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 91, 0),
(92, '2026-07-12', '2026-07-12', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 92, 0),
(93, '2026-07-18', '2026-07-18', 1, 'Jose Rivas', 3, 'Entrega completada', 1, 93, 0),
(94, '2026-07-19', '2026-07-19', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 94, 0),
(95, '2026-07-17', '2026-07-17', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 95, 0),
(96, '2026-07-19', '2026-07-19', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 96, 0),
(97, '2026-07-24', '2026-07-24', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 97, 0),
(98, '2026-07-24', '2026-07-24', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 98, 0),
(99, '2026-07-27', '2026-07-27', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 99, 0),
(100, '2026-07-30', '2026-07-30', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 100, 0),
(101, '2026-07-30', '2026-07-30', 1, 'Jose Rivas', 3, 'Entrega completada', 1, 101, 0),
(102, '2026-08-01', '2026-08-01', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 102, 0),
(103, '2026-08-03', '2026-08-03', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 103, 0),
(104, '2026-08-07', '2026-08-07', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 104, 0),
(105, '2026-08-10', '2026-08-10', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 105, 0),
(106, '2026-08-10', '2026-08-10', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 106, 0),
(107, '2026-08-10', '2026-08-10', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 107, 0),
(108, '2026-08-11', '2026-08-11', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 108, 0),
(109, '2026-08-14', '2026-08-14', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 109, 0),
(110, '2026-08-13', '2026-08-13', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 110, 0),
(111, '2026-08-17', '2026-08-17', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 111, 0),
(112, '2026-08-17', '2026-08-17', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 112, 0),
(113, '2026-08-21', '2026-08-21', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 113, 0),
(114, '2026-08-21', '2026-08-21', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 114, 0),
(115, '2026-08-23', '2026-08-23', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 115, 0),
(116, '2026-08-23', '2026-08-23', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 116, 0),
(117, '2026-08-24', '2026-08-24', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 117, 0),
(118, '2026-08-25', '2026-08-25', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 118, 0),
(119, '2026-08-30', '2026-08-30', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 119, 0),
(120, '2026-09-01', '2026-09-01', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 120, 0),
(121, '2026-09-03', '2026-09-03', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 121, 0),
(122, '2026-09-03', '2026-09-03', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 122, 0),
(123, '2026-09-04', '2026-09-04', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 123, 0),
(124, '2026-09-06', '2026-09-06', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 124, 0),
(125, '2026-09-08', '2026-09-08', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 125, 0),
(126, '2026-09-09', '2026-09-09', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 126, 0),
(127, '2026-09-09', '2026-09-09', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 127, 0),
(128, '2026-09-09', '2026-09-09', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 128, 0),
(129, '2026-09-10', '2026-09-10', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 129, 0),
(130, '2026-09-13', '2026-09-13', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 130, 0),
(131, '2026-09-18', '2026-09-18', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 131, 0),
(132, '2026-09-18', '2026-09-18', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 132, 0),
(133, '2026-09-18', '2026-09-18', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 133, 0),
(134, '2026-09-18', '2026-09-18', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 134, 0),
(135, '2026-09-24', '2026-09-24', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 135, 0),
(136, '2026-09-26', '2026-09-26', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 136, 0),
(137, '2026-09-30', '2026-09-30', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 137, 0),
(138, '2026-10-05', '2026-10-05', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 138, 0),
(139, '2026-10-06', '2026-10-06', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 139, 0),
(140, '2026-10-11', '2026-10-11', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 140, 0),
(141, '2026-10-11', '2026-10-11', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 141, 0),
(142, '2026-10-13', '2026-10-13', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 142, 0),
(143, '2026-10-13', '2026-10-13', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 143, 0),
(144, '2026-10-18', '2026-10-18', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 144, 0),
(145, '2026-10-17', '2026-10-17', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 145, 0),
(146, '2026-10-18', '2026-10-18', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 146, 0),
(147, '2026-10-18', '2026-10-18', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 147, 0),
(148, '2026-10-22', '2026-10-22', 1, 'Pedro Gimenez', 2, 'Entrega completada', 1, 148, 0),
(149, '2026-10-21', '2026-10-21', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 149, 0),
(150, '2026-10-21', '2026-10-21', 1, 'Carlos Mendoza', 1, 'Entrega completada', 1, 150, 0),
(151, '2026-10-23', '2026-10-23', 1, 'Pedro Gimenez', 1, 'Entrega completada', 1, 151, 0),
(152, '2026-10-23', '2026-10-23', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 152, 0),
(153, '2026-10-28', '2026-10-28', 1, 'Carlos Mendoza', 2, 'Entrega completada', 1, 153, 0),
(154, '2026-10-31', '2026-10-31', 1, 'Jose Rivas', 3, 'Entrega completada', 1, 154, 0),
(155, '2026-11-03', '2026-11-03', 1, 'Jose Rivas', 2, 'Entrega completada', 1, 155, 0),
(156, '2026-11-05', '2026-11-05', 1, 'Jose Rivas', 1, 'Entrega completada', 1, 156, 0),
(157, '2026-11-06', NULL, 2, 'Carlos Mendoza', 1, 'En camino', 1, 157, 0),
(158, '2026-11-07', NULL, 2, 'Jose Rivas', 1, 'En camino', 1, 158, 0);

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
(334, 1, 1, 30444555, 'Av Principal de Santa Rosa', '02510001104', 240, '', 1),
(335, 2, 2, 17100998, 'Av Pedro leon con calle 54', '02511358621', 240, '', 1),
(336, 3, 3, 17100998, 'Av Pedro leon con calle 54', '02511358621', 240, '', 1),
(337, 4, 4, 25566585, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 260, '', 1),
(338, 5, 5, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 280, '', 1),
(339, 6, 6, 32200771, 'Calle 54 con Carrera 20', '02514408820', 220, '', 1),
(340, 7, 7, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 220, '', 1),
(341, 8, 8, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 260, '', 1),
(342, 9, 9, 30444555, 'Av Principal de Santa Rosa', '02510001104', 260, '', 1),
(343, 10, 10, 30555666, 'Plaza Bolivar, local 2', '04120001105', 250, '', 1),
(344, 11, 11, 30555666, 'Plaza Bolivar, local 2', '04120001105', 270, '', 1),
(345, 12, 12, 32200771, 'Calle 54 con Carrera 20', '02514408820', 240, '', 1),
(346, 13, 13, 30555666, 'Plaza Bolivar, local 2', '04120001105', 140, '', 1),
(347, 14, 14, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 230, '', 1),
(348, 15, 15, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 260, '', 1),
(349, 16, 16, 30444555, 'Av Principal de Santa Rosa', '02510001104', 270, '', 1),
(350, 17, 17, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 200, '', 1),
(351, 18, 18, 32200771, 'Calle 54 con Carrera 20', '02514408820', 260, '', 1),
(352, 19, 19, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 250, '', 1),
(353, 20, 20, 30666777, 'Av Venezuela con calle 12', '02510001106', 220, '', 1),
(354, 21, 21, 25566580, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 240, '', 1),
(355, 22, 22, 30666777, 'Av Venezuela con calle 12', '02510001106', 240, '', 1),
(356, 23, 23, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 160, '', 1),
(357, 24, 24, 25566585, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 230, '', 1),
(358, 25, 25, 17100998, 'Av Pedro leon con calle 54', '02511358621', 190, '', 1),
(359, 26, 26, 30111222, 'Carrera 19 con calle 30', '04120001101', 260, '', 1),
(360, 27, 27, 30444555, 'Av Principal de Santa Rosa', '02510001104', 130, '', 1),
(361, 28, 28, 32200771, 'Calle 54 con Carrera 20', '02514408820', 210, '', 1),
(362, 29, 29, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 260, '', 1),
(363, 30, 30, 32200771, 'Calle 54 con Carrera 20', '02514408820', 220, '', 1),
(364, 31, 31, 32200771, 'Calle 54 con Carrera 20', '02514408820', 280, '', 1),
(365, 32, 32, 25566582, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 250, '', 1),
(366, 33, 33, 17100998, 'Av Pedro leon con calle 54', '02511358621', 160, '', 1),
(367, 34, 34, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 270, '', 1),
(368, 35, 35, 30666777, 'Av Venezuela con calle 12', '02510001106', 160, '', 1),
(369, 36, 36, 30111222, 'Carrera 19 con calle 30', '04120001101', 250, '', 1),
(370, 37, 37, 30444555, 'Av Principal de Santa Rosa', '02510001104', 240, '', 1),
(371, 38, 38, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 250, '', 1),
(372, 39, 39, 32200771, 'Calle 54 con Carrera 20', '02514408820', 270, '', 1),
(373, 40, 40, 30555666, 'Plaza Bolivar, local 2', '04120001105', 230, '', 1),
(374, 41, 41, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 240, '', 1),
(375, 42, 42, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 260, '', 1),
(376, 43, 43, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 220, '', 1),
(377, 44, 44, 17100998, 'Av Pedro leon con calle 54', '02511358621', 130, '', 1),
(378, 45, 45, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 130, '', 1),
(379, 46, 46, 30111222, 'Carrera 19 con calle 30', '04120001101', 120, '', 1),
(380, 47, 47, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 180, '', 1),
(381, 48, 48, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 180, '', 1),
(382, 49, 49, 32200771, 'Calle 54 con Carrera 20', '02514408820', 130, '', 1),
(383, 50, 50, 25566585, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 130, '', 1),
(384, 51, 51, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 270, '', 1),
(385, 52, 52, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 250, '', 1),
(386, 53, 53, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 220, '', 1),
(387, 54, 54, 30666777, 'Av Venezuela con calle 12', '02510001106', 240, '', 1),
(388, 55, 55, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 130, '', 1),
(389, 56, 56, 17100998, 'Av Pedro leon con calle 54', '02511358621', 190, '', 1),
(390, 57, 57, 17100998, 'Av Pedro leon con calle 54', '02511358621', 260, '', 1),
(391, 58, 58, 30444555, 'Av Principal de Santa Rosa', '02510001104', 250, '', 1),
(392, 59, 59, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 230, '', 1),
(393, 60, 60, 25566585, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 270, '', 1),
(394, 61, 61, 32200771, 'Calle 54 con Carrera 20', '02514408820', 140, '', 1),
(395, 62, 62, 30666777, 'Av Venezuela con calle 12', '02510001106', 240, '', 1),
(396, 63, 63, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 260, '', 1),
(397, 64, 64, 17100998, 'Av Pedro leon con calle 54', '02511358621', 250, '', 1),
(398, 65, 65, 17100998, 'Av Pedro leon con calle 54', '02511358621', 140, '', 1),
(399, 66, 66, 30666777, 'Av Venezuela con calle 12', '02510001106', 170, '', 1),
(400, 67, 67, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 160, '', 1),
(401, 68, 68, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 270, '', 1),
(402, 69, 69, 30444555, 'Av Principal de Santa Rosa', '02510001104', 220, '', 1),
(403, 70, 70, 25566582, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 240, '', 1),
(404, 71, 71, 30666777, 'Av Venezuela con calle 12', '02510001106', 260, '', 1),
(405, 72, 72, 30444555, 'Av Principal de Santa Rosa', '02510001104', 210, '', 1),
(406, 73, 73, 30444555, 'Av Principal de Santa Rosa', '02510001104', 180, '', 1),
(407, 74, 74, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 230, '', 1),
(408, 75, 75, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 140, '', 1),
(409, 76, 76, 14555666, 'Urb Del Este, calle 5', '04120001107', 250, '', 1),
(410, 77, 77, 30666777, 'Av Venezuela con calle 12', '02510001106', 150, '', 1),
(411, 78, 78, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 200, '', 1),
(412, 79, 79, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 130, '', 1),
(413, 80, 80, 30111222, 'Carrera 19 con calle 30', '04120001101', 220, '', 1),
(414, 81, 81, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 210, '', 1),
(415, 82, 82, 19888777, 'Barrio El Jebe, calle 3', '04120001108', 120, '', 1),
(416, 83, 83, 32200771, 'Calle 54 con Carrera 20', '02514408820', 250, '', 1),
(417, 84, 84, 30666777, 'Av Venezuela con calle 12', '02510001106', 260, '', 1),
(418, 85, 85, 25566585, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 280, '', 1),
(419, 86, 86, 30666777, 'Av Venezuela con calle 12', '02510001106', 280, '', 1),
(420, 87, 87, 32200771, 'Calle 54 con Carrera 20', '02514408820', 280, '', 1),
(421, 88, 88, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 180, '', 1),
(422, 89, 89, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 180, '', 1),
(423, 90, 90, 30555666, 'Plaza Bolivar, local 2', '04120001105', 140, '', 1),
(424, 91, 91, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 200, '', 1),
(425, 92, 92, 14555666, 'Urb Del Este, calle 5', '04120001107', 260, '', 1),
(426, 93, 93, 32200771, 'Calle 54 con Carrera 20', '02514408820', 100, '', 1),
(427, 94, 94, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 200, '', 1),
(428, 95, 95, 17100998, 'Av Pedro leon con calle 54', '02511358621', 260, '', 1),
(429, 96, 96, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 220, '', 1),
(430, 97, 97, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 270, '', 1),
(431, 98, 98, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 280, '', 1),
(432, 99, 99, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 250, '', 1),
(433, 100, 100, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 130, '', 1),
(434, 101, 101, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 100, '', 1),
(435, 102, 102, 30444555, 'Av Principal de Santa Rosa', '02510001104', 180, '', 1),
(436, 103, 103, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 210, '', 1),
(437, 104, 104, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 210, '', 1),
(438, 105, 105, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 250, '', 1),
(439, 106, 106, 30666777, 'Av Venezuela con calle 12', '02510001106', 250, '', 1),
(440, 107, 107, 17100998, 'Av Pedro leon con calle 54', '02511358621', 180, '', 1),
(441, 108, 108, 30555666, 'Plaza Bolivar, local 2', '04120001105', 210, '', 1),
(442, 109, 109, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 250, '', 1),
(443, 110, 110, 17100998, 'Av Pedro leon con calle 54', '02511358621', 260, '', 1),
(444, 111, 111, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 120, '', 1),
(445, 112, 112, 30555666, 'Plaza Bolivar, local 2', '04120001105', 250, '', 1),
(446, 113, 113, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 120, '', 1),
(447, 114, 114, 19888777, 'Barrio El Jebe, calle 3', '04120001108', 260, '', 1),
(448, 115, 115, 30111222, 'Carrera 19 con calle 30', '04120001101', 160, '', 1),
(449, 116, 116, 17100998, 'Av Pedro leon con calle 54', '02511358621', 230, '', 1),
(450, 117, 117, 30111222, 'Carrera 19 con calle 30', '04120001101', 250, '', 1),
(451, 118, 118, 17100998, 'Av Pedro leon con calle 54', '02511358621', 270, '', 1),
(452, 119, 119, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 280, '', 1),
(453, 120, 120, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 140, '', 1),
(454, 121, 121, 30444555, 'Av Principal de Santa Rosa', '02510001104', 220, '', 1),
(455, 122, 122, 31039811, 'Av Urb Patarata con Calle 20', '02513213495', 240, '', 1),
(456, 123, 123, 30666777, 'Av Venezuela con calle 12', '02510001106', 110, '', 1),
(457, 124, 124, 32200771, 'Calle 54 con Carrera 20', '02514408820', 210, '', 1),
(458, 125, 125, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 210, '', 1),
(459, 126, 126, 30666777, 'Av Venezuela con calle 12', '02510001106', 230, '', 1),
(460, 127, 127, 25566580, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 170, '', 1),
(461, 128, 128, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 210, '', 1),
(462, 129, 129, 17100998, 'Av Pedro leon con calle 54', '02511358621', 240, '', 1),
(463, 130, 130, 30555666, 'Plaza Bolivar, local 2', '04120001105', 270, '', 1),
(464, 131, 131, 17100998, 'Av Pedro leon con calle 54', '02511358621', 130, '', 1),
(465, 132, 132, 30444555, 'Av Principal de Santa Rosa', '02510001104', 150, '', 1),
(466, 133, 133, 17100998, 'Av Pedro leon con calle 54', '02511358621', 160, '', 1),
(467, 134, 134, 30666777, 'Av Venezuela con calle 12', '02510001106', 270, '', 1),
(468, 135, 135, 14555666, 'Urb Del Este, calle 5', '04120001107', 250, '', 1),
(469, 136, 136, 30111222, 'Carrera 19 con calle 30', '04120001101', 250, '', 1),
(470, 137, 137, 17100998, 'Av Pedro leon con calle 54', '02511358621', 170, '', 1),
(471, 138, 138, 17100998, 'Av Pedro leon con calle 54', '02511358621', 130, '', 1),
(472, 139, 139, 32200771, 'Calle 54 con Carrera 20', '02514408820', 270, '', 1),
(473, 140, 140, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 140, '', 1),
(474, 141, 141, 17100998, 'Av Pedro leon con calle 54', '02511358621', 150, '', 1),
(475, 142, 142, 30111222, 'Carrera 19 con calle 30', '04120001101', 110, '', 1),
(476, 143, 143, 17100998, 'Av Pedro leon con calle 54', '02511358621', 230, '', 1),
(477, 144, 144, 32200771, 'Calle 54 con Carrera 20', '02514408820', 170, '', 1),
(478, 145, 145, 32200771, 'Calle 54 con Carrera 20', '02514408820', 230, '', 1),
(479, 146, 146, 25566585, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 160, '', 1),
(480, 147, 147, 30444555, 'Av Principal de Santa Rosa', '02510001104', 270, '', 1),
(481, 148, 148, 17100998, 'Av Pedro leon con calle 54', '02511358621', 110, '', 1),
(482, 149, 149, 30111222, 'Carrera 19 con calle 30', '04120001101', 170, '', 1),
(483, 150, 150, 30666777, 'Av Venezuela con calle 12', '02510001106', 230, '', 1),
(484, 151, 151, 30666777, 'Av Venezuela con calle 12', '02510001106', 280, '', 1),
(485, 152, 152, 30111222, 'Carrera 19 con calle 30', '04120001101', 240, '', 1),
(486, 153, 153, 30222333, 'Calle 42 entre carreras 25 y 26', '04120001102', 130, '', 1),
(487, 154, 154, 30444555, 'Av Principal de Santa Rosa', '02510001104', 100, '', 1),
(488, 155, 155, 25566585, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 150, '', 1),
(489, 156, 156, 30555666, 'Plaza Bolivar, local 2', '04120001105', 270, '', 1),
(490, 157, 157, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 260, '', 1),
(491, 158, 158, 30333444, 'Zona Industrial I, galpon 8', '02510001103', 250, '', 1);

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
  `fecha_registro` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `materia_prima`
--

INSERT INTO `materia_prima` (`id_materia_prima`, `nombre_materia_prima`, `descripcion_materia_prima`, `id_unidad_medida`, `stock_actual`, `id_proveedor`, `fecha_registro`, `status`) VALUES
(1, 'Harina de Trigo', 'Harina para elaboracion de galletas', 1, 515, 12321234, '2026-01-02 08:00:00.000000', 1),
(2, 'Huevos', 'Elaboracion de galletas a base de huevo', 5, 340, 17100998, '2026-01-02 08:00:00.000000', 1),
(3, 'Azucar Nevada', 'Para la dulzura de galletas', 1, 240, 31039711, '2026-01-02 08:00:00.000000', 1),
(4, 'Margarina', 'Materia grasa para galletas', 3, 245, 12321234, '2026-01-02 08:00:00.000000', 1),
(10, 'Cacao', 'Para elaboracion de galletas de chocolate', 2, 25, 31039711, '2026-01-02 08:00:00.000000', 1);

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
-- Estructura de tabla para la tabla `monedas`
--

CREATE TABLE `monedas` (
  `id_moneda` int(11) NOT NULL,
  `nombre_moneda` varchar(50) NOT NULL,
  `descripcion_moneda` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `monedas`
--

INSERT INTO `monedas` (`id_moneda`, `nombre_moneda`, `descripcion_moneda`, `status`) VALUES
(1, 'Dolar USD', 'moneda principal de conversion', 1),
(2, 'Euro EUR', 'moneda secundaria en el sistema', 1),
(3, 'USDT', 'Cryptomoneda digital', 1),
(4, 'Bolivares', 'moneda oficial del pais', 1),
(5, 'Pesos', 'moneda para proveedores mexicanos', 1);

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
(330, 1, 740.00, '2026-01-29 15:00:00.000000', '20260000001', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(331, 2, 360.00, '2026-01-25 15:00:00.000000', '20260000002', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(332, 3, 535.00, '2026-01-25 15:00:00.000000', '20260000003', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(333, 4, 650.00, '2026-02-06 15:00:00.000000', '20260000004', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(334, 5, 469.00, '2026-01-31 15:00:00.000000', '20260000005', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(335, 6, 490.00, '2026-01-27 15:00:00.000000', '20260000006', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(336, 7, 330.00, '2026-01-22 15:00:00.000000', '20260000007', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(337, 8, 650.00, '2026-01-28 15:00:00.000000', '20260000008', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(338, 9, 650.00, '2026-01-28 15:00:00.000000', '20260000009', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(339, 10, 515.00, '2026-02-12 15:00:00.000000', '20260000010', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(340, 11, 525.50, '2026-02-11 15:00:00.000000', '20260000011', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(341, 12, 360.00, '2026-02-18 15:00:00.000000', '20260000012', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(342, 13, 210.00, '2026-03-02 15:00:00.000000', '20260000013', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(343, 14, 575.00, '2026-02-16 15:00:00.000000', '20260000014', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(344, 15, 650.00, '2026-03-04 15:00:00.000000', '20260000015', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(345, 16, 675.00, '2026-02-26 15:00:00.000000', '20260000016', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(346, 17, 400.00, '2026-02-17 15:00:00.000000', '20260000017', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(347, 18, 650.00, '2026-03-04 15:00:00.000000', '20260000018', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(348, 19, 625.00, '2026-03-05 15:00:00.000000', '20260000019', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(349, 20, 490.00, '2026-03-03 15:00:00.000000', '20260000020', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(350, 21, 840.00, '2026-03-10 15:00:00.000000', '20260000021', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(351, 22, 360.00, '2026-03-15 15:00:00.000000', '20260000022', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(352, 23, 400.00, '2026-03-14 15:00:00.000000', '20260000023', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(353, 24, 400.00, '2026-03-02 15:00:00.000000', '20260000024', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(354, 25, 475.00, '2026-03-04 15:00:00.000000', '20260000025', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(355, 26, 910.00, '2026-03-19 15:00:00.000000', '20260000026', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(356, 27, 195.00, '2026-03-22 15:00:00.000000', '20260000027', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(357, 28, 315.00, '2026-04-08 15:00:00.000000', '20260000028', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(358, 29, 390.00, '2026-03-18 15:00:00.000000', '20260000029', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(359, 30, 470.80, '2026-04-06 15:00:00.000000', '20260000030', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(360, 31, 840.00, '2026-04-04 15:00:00.000000', '20260000031', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(361, 32, 555.00, '2026-04-12 15:00:00.000000', '20260000032', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(362, 33, 240.00, '2026-03-30 15:00:00.000000', '20260000033', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(363, 34, 405.00, '2026-04-02 15:00:00.000000', '20260000034', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(364, 35, 400.00, '2026-04-05 15:00:00.000000', '20260000035', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(365, 36, 595.00, '2026-04-20 15:00:00.000000', '20260000036', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(366, 37, 710.00, '2026-04-11 15:00:00.000000', '20260000037', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(367, 38, 466.00, '2026-04-18 15:00:00.000000', '20260000038', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(368, 39, 675.00, '2026-04-05 15:00:00.000000', '20260000039', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(369, 40, 585.00, '2026-04-10 15:00:00.000000', '20260000040', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(370, 41, 740.00, '2026-04-21 15:00:00.000000', '20260000041', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(371, 42, 770.00, '2026-04-10 15:00:00.000000', '20260000042', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(372, 43, 670.00, '2026-05-02 15:00:00.000000', '20260000043', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(373, 44, 455.00, '2026-04-25 15:00:00.000000', '20260000044', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(374, 45, 455.00, '2026-04-15 15:00:00.000000', '20260000045', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(375, 46, 300.00, '2026-04-22 15:00:00.000000', '20260000046', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(376, 48, 450.00, '2026-05-10 15:00:00.000000', '20260000047', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(377, 50, 195.00, '2026-04-23 15:00:00.000000', '20260000048', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(378, 51, 610.00, '2026-04-28 15:00:00.000000', '20260000049', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(379, 52, 505.00, '2026-04-27 15:00:00.000000', '20260000050', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(380, 53, 550.00, '2026-05-14 15:00:00.000000', '20260000051', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(381, 54, 630.00, '2026-05-05 15:00:00.000000', '20260000052', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(382, 55, 227.50, '2026-05-17 15:00:00.000000', '20260000053', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(383, 56, 475.00, '2026-05-12 15:00:00.000000', '20260000054', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(384, 57, 487.50, '2026-05-20 15:00:00.000000', '20260000055', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(385, 58, 542.50, '2026-05-15 15:00:00.000000', '20260000056', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(386, 59, 575.00, '2026-05-17 15:00:00.000000', '20260000057', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(387, 60, 540.00, '2026-05-16 15:00:00.000000', '20260000058', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(388, 61, 280.00, '2026-05-28 15:00:00.000000', '20260000059', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(389, 62, 560.00, '2026-06-12 15:00:00.000000', '20260000060', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(390, 63, 580.00, '2026-06-10 15:00:00.000000', '20260000061', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(391, 64, 875.00, '2026-06-04 15:00:00.000000', '20260000062', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(392, 65, 350.00, '2026-06-05 15:00:00.000000', '20260000063', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(393, 66, 340.00, '2026-06-17 15:00:00.000000', '20260000064', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(394, 67, 320.00, '2026-06-20 15:00:00.000000', '20260000065', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(395, 68, 675.00, '2026-06-18 15:00:00.000000', '20260000066', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(396, 69, 495.00, '2026-06-21 15:00:00.000000', '20260000067', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(397, 70, 550.00, '2026-06-24 15:00:00.000000', '20260000068', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(398, 71, 650.00, '2026-06-21 15:00:00.000000', '20260000069', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(399, 72, 515.00, '2026-06-24 15:00:00.000000', '20260000070', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(400, 73, 450.00, '2026-06-27 15:00:00.000000', '20260000071', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(401, 74, 695.00, '2026-06-17 15:00:00.000000', '20260000072', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(402, 75, 280.00, '2026-07-08 15:00:00.000000', '20260000073', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(403, 76, 375.00, '2026-07-09 15:00:00.000000', '20260000074', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(404, 77, 375.00, '2026-07-08 15:00:00.000000', '20260000075', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(405, 78, 700.00, '2026-07-01 15:00:00.000000', '20260000076', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(406, 79, 195.00, '2026-07-03 15:00:00.000000', '20260000077', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(407, 80, 390.00, '2026-06-29 15:00:00.000000', '20260000078', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(408, 81, 635.00, '2026-07-18 15:00:00.000000', '20260000079', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(409, 82, 180.00, '2026-06-30 15:00:00.000000', '20260000080', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(410, 83, 435.00, '2026-07-20 15:00:00.000000', '20260000081', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(411, 84, 650.00, '2026-07-19 15:00:00.000000', '20260000082', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(412, 85, 700.00, '2026-07-14 15:00:00.000000', '20260000083', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(413, 86, 700.00, '2026-07-14 15:00:00.000000', '20260000084', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(414, 87, 700.00, '2026-07-29 15:00:00.000000', '20260000085', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(415, 89, 360.00, '2026-07-09 15:00:00.000000', '20260000086', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(416, 90, 280.00, '2026-07-11 15:00:00.000000', '20260000087', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(417, 91, 700.00, '2026-07-13 15:00:00.000000', '20260000088', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(418, 92, 460.00, '2026-07-18 15:00:00.000000', '20260000089', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(419, 93, 250.00, '2026-07-17 15:00:00.000000', '20260000090', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(420, 94, 500.00, '2026-08-04 15:00:00.000000', '20260000091', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(421, 95, 585.00, '2026-07-18 15:00:00.000000', '20260000092', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(422, 96, 330.00, '2026-07-21 15:00:00.000000', '20260000093', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(423, 97, 540.00, '2026-08-10 15:00:00.000000', '20260000094', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(424, 98, 560.00, '2026-08-01 15:00:00.000000', '20260000095', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(425, 99, 625.00, '2026-07-28 15:00:00.000000', '20260000096', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(426, 100, 455.00, '2026-08-02 15:00:00.000000', '20260000097', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(427, 101, 200.00, '2026-08-18 15:00:00.000000', '20260000098', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(428, 102, 450.00, '2026-08-14 15:00:00.000000', '20260000099', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(429, 104, 420.00, '2026-08-09 15:00:00.000000', '20260000100', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(430, 105, 500.00, '2026-08-29 15:00:00.000000', '20260000101', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(431, 106, 375.00, '2026-08-08 15:00:00.000000', '20260000102', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(432, 107, 360.00, '2026-08-25 15:00:00.000000', '20260000103', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(433, 108, 735.00, '2026-08-11 15:00:00.000000', '20260000104', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(434, 109, 555.00, '2026-08-23 15:00:00.000000', '20260000105', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(435, 110, 390.00, '2026-08-28 15:00:00.000000', '20260000106', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(436, 111, 300.00, '2026-08-18 15:00:00.000000', '20260000107', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(437, 112, 565.00, '2026-08-31 15:00:00.000000', '20260000108', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(438, 113, 420.00, '2026-08-24 15:00:00.000000', '20260000109', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(439, 114, 520.00, '2026-08-26 15:00:00.000000', '20260000110', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(440, 115, 240.00, '2026-08-26 15:00:00.000000', '20260000111', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(441, 116, 805.00, '2026-09-14 15:00:00.000000', '20260000112', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(442, 117, 745.00, '2026-08-25 15:00:00.000000', '20260000113', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(443, 118, 610.00, '2026-09-03 15:00:00.000000', '20260000114', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(444, 119, 840.00, '2026-09-21 15:00:00.000000', '20260000115', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(445, 120, 490.00, '2026-09-20 15:00:00.000000', '20260000116', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(446, 121, 430.00, '2026-09-05 15:00:00.000000', '20260000117', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(447, 122, 470.00, '2026-09-21 15:00:00.000000', '20260000118', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(448, 124, 315.00, '2026-09-28 15:00:00.000000', '20260000119', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(449, 125, 455.00, '2026-09-11 15:00:00.000000', '20260000120', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(450, 126, 575.00, '2026-09-29 15:00:00.000000', '20260000121', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(451, 127, 595.00, '2026-09-29 15:00:00.000000', '20260000122', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(452, 128, 735.00, '2026-09-18 15:00:00.000000', '20260000123', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(453, 129, 600.00, '2026-09-11 15:00:00.000000', '20260000124', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(454, 130, 735.00, '2026-10-04 15:00:00.000000', '20260000125', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(455, 131, 455.00, '2026-10-04 15:00:00.000000', '20260000126', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(456, 132, 375.00, '2026-10-04 15:00:00.000000', '20260000127', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(457, 133, 400.00, '2026-09-25 15:00:00.000000', '20260000128', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(458, 134, 405.00, '2026-10-02 15:00:00.000000', '20260000129', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(459, 135, 541.00, '2026-09-30 15:00:00.000000', '20260000130', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(460, 136, 500.00, '2026-10-08 15:00:00.000000', '20260000131', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(461, 137, 425.00, '2026-10-11 15:00:00.000000', '20260000132', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(462, 138, 325.00, '2026-10-13 15:00:00.000000', '20260000133', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(463, 139, 675.00, '2026-10-10 15:00:00.000000', '20260000134', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(464, 140, 280.00, '2026-10-29 15:00:00.000000', '20260000135', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(465, 141, 225.00, '2026-10-29 15:00:00.000000', '20260000136', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(466, 142, 165.00, '2026-10-25 15:00:00.000000', '20260000137', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(467, 143, 153.00, '2026-10-27 15:00:00.000000', '20260000138', 'Abono inicial', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(468, 145, 525.00, '2026-10-19 15:00:00.000000', '20260000139', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(469, 147, 270.00, '2026-11-09 15:00:00.000000', '20260000140', 'Abono inicial', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(470, 148, 275.00, '2026-11-04 15:00:00.000000', '20260000141', 'Pago completo', 3, 'assets/img/pagos/fondo_paisaje.jpg'),
(471, 149, 340.00, '2026-10-31 15:00:00.000000', '20260000142', 'Pago completo', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(472, 150, 460.00, '2026-11-09 15:00:00.000000', '20260000143', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(473, 151, 385.00, '2026-10-28 15:00:00.000000', '20260000144', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(474, 152, 630.00, '2026-11-09 15:00:00.000000', '20260000145', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(475, 156, 535.00, '2026-11-09 15:00:00.000000', '20260000146', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(476, 157, 260.00, '2026-11-07 15:00:00.000000', '20260000147', 'Abono inicial', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(477, 158, 437.50, '2026-11-09 15:00:00.000000', '20260000148', 'Pago completo', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(478, 159, 146.00, '2026-11-09 15:00:00.000000', '20260000149', 'Abono inicial', 2, 'assets/img/pagos/fondo_paisaje.jpg'),
(479, 161, 260.00, '2026-11-09 15:00:00.000000', '20260000150', 'Abono inicial', 1, 'assets/img/pagos/fondo_paisaje.jpg'),
(480, 162, 545.00, '2026-11-17 16:57:21.000000', '12387689041', 'Pago pedido #162', 1, 'assets/img/pagos/pago_20261117_165721_3a7d98dc.jpg');

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
(69, 1, 1588.00, 2026, 1, '20260000151', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(70, 2, 168.00, 2026, 1, '20260000152', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(71, 3, 319.00, 2026, 1, '20260000153', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(72, 4, 891.00, 2026, 1, '20260000154', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(73, 5, 92.00, 2026, 1, '20260000155', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(74, 6, 165.00, 2026, 1, '20260000156', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(75, 7, 1098.00, 2026, 1, '20260000157', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(76, 8, 116.00, 2026, 1, '20260000158', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(77, 10, 964.00, 2026, 1, '20260000159', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(78, 11, 104.00, 2026, 1, '20260000160', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(79, 12, 209.00, 2026, 1, '20260000161', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(80, 13, 1208.00, 2026, 1, '20260000162', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(81, 14, 128.00, 2026, 1, '20260000163', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(82, 15, 187.00, 2026, 1, '20260000164', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(83, 16, 964.00, 2026, 1, '20260000165', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(84, 17, 104.00, 2026, 1, '20260000166', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(85, 18, 187.00, 2026, 1, '20260000167', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(86, 19, 1330.00, 2026, 1, '20260000168', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(87, 20, 140.00, 2026, 1, '20260000169', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(88, 21, 220.00, 2026, 1, '20260000170', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(89, 22, 1318.00, 2026, 1, '20260000171', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(90, 23, 136.00, 2026, 1, '20260000172', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(91, 24, 209.00, 2026, 1, '20260000173', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(92, 25, 1147.00, 2026, 1, '20260000174', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(93, 26, 120.00, 2026, 1, '20260000175', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(94, 27, 209.00, 2026, 1, '20260000176', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(95, 28, 964.00, 2026, 1, '20260000177', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(96, 29, 104.00, 2026, 1, '20260000178', 'Pago completo', 'assets/img/pagos/fondo_paisaje.jpg'),
(97, 30, 77.00, 2026, 1, '20260000179', 'Abono inicial', 'assets/img/pagos/fondo_paisaje.jpg'),
(98, 33, 60.50, 2026, 1, '20260000180', 'Abono inicial', 'assets/img/pagos/fondo_paisaje.jpg');

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
(1, 30444555, '2026-01-06 08:01:00.000000', 5, 2, 740.00, 'Av Principal de Santa Rosa', '02510001104', 'Despacho a tienda', NULL, 1, 1),
(2, 17100998, '2026-01-06 15:48:00.000000', 5, 2, 360.00, 'Av Pedro leon con calle 54', '02511358621', 'Reposicion de anaqueles', NULL, 1, 1),
(3, 17100998, '2026-01-09 10:00:00.000000', 5, 2, 535.00, 'Av Pedro leon con calle 54', '02511358621', 'Entrega en horario de manana', NULL, 1, 1),
(4, 25566585, '2026-01-17 12:09:00.000000', 5, 2, 650.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Pedido a credito', NULL, 1, 1),
(5, 30333444, '2026-01-17 11:53:00.000000', 5, 2, 469.00, 'Zona Industrial I, galpon 8', '02510001103', 'Despacho a tienda', 1, 1, 1),
(6, 32200771, '2026-01-19 15:46:00.000000', 5, 2, 490.00, 'Calle 54 con Carrera 20', '02514408820', 'Despacho a tienda', NULL, 1, 1),
(7, 31039811, '2026-01-19 13:52:00.000000', 5, 2, 330.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Reposicion de anaqueles', NULL, 1, 1),
(8, 30222333, '2026-01-21 12:45:00.000000', 5, 2, 650.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Pedido a credito', NULL, 1, 1),
(9, 30444555, '2026-01-24 09:14:00.000000', 5, 2, 650.00, 'Av Principal de Santa Rosa', '02510001104', 'Pedido a credito', NULL, 1, 1),
(10, 30555666, '2026-01-26 16:19:00.000000', 5, 2, 515.00, 'Plaza Bolivar, local 2', '04120001105', 'Entrega en horario de manana', NULL, 1, 1),
(11, 30555666, '2026-01-26 15:15:00.000000', 5, 2, 525.50, 'Plaza Bolivar, local 2', '04120001105', 'Reposicion de anaqueles', 1, 1, 1),
(12, 32200771, '2026-01-28 12:10:00.000000', 5, 2, 360.00, 'Calle 54 con Carrera 20', '02514408820', 'Pedido a credito', NULL, 1, 1),
(13, 30555666, '2026-02-07 08:39:00.000000', 5, 2, 210.00, 'Plaza Bolivar, local 2', '04120001105', 'Despacho a tienda', NULL, 3, 1),
(14, 30333444, '2026-02-09 12:53:00.000000', 5, 2, 575.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido a credito', NULL, 3, 1),
(15, 31039811, '2026-02-13 16:18:00.000000', 5, 2, 650.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido del mes', NULL, 3, 1),
(16, 30444555, '2026-02-13 08:26:00.000000', 5, 2, 675.00, 'Av Principal de Santa Rosa', '02510001104', 'Entrega en horario de manana', NULL, 3, 1),
(17, 30333444, '2026-02-17 14:22:00.000000', 5, 2, 400.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido del mes', NULL, 3, 1),
(18, 32200771, '2026-02-19 14:30:00.000000', 5, 2, 650.00, 'Calle 54 con Carrera 20', '02514408820', 'Reposicion de anaqueles', NULL, 3, 1),
(19, 31039811, '2026-02-21 09:07:00.000000', 5, 2, 625.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Reposicion de anaqueles', NULL, 3, 1),
(20, 30666777, '2026-02-21 09:26:00.000000', 5, 2, 490.00, 'Av Venezuela con calle 12', '02510001106', 'Reposicion de anaqueles', NULL, 3, 1),
(21, 25566580, '2026-02-24 13:42:00.000000', 5, 2, 840.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Reposicion de anaqueles', NULL, 3, 1),
(22, 30666777, '2026-02-28 11:55:00.000000', 5, 2, 360.00, 'Av Venezuela con calle 12', '02510001106', 'Entrega en horario de manana', NULL, 3, 1),
(23, 30222333, '2026-02-28 11:09:00.000000', 5, 2, 400.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Pedido a credito', NULL, 3, 1),
(24, 25566585, '2026-02-28 14:48:00.000000', 5, 2, 400.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Reposicion de anaqueles', NULL, 3, 1),
(25, 17100998, '2026-03-03 09:28:00.000000', 5, 2, 475.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido a credito', NULL, 5, 1),
(26, 30111222, '2026-03-06 08:26:00.000000', 5, 2, 910.00, 'Carrera 19 con calle 30', '04120001101', 'Reposicion de anaqueles', NULL, 5, 1),
(27, 30444555, '2026-03-11 11:27:00.000000', 5, 2, 195.00, 'Av Principal de Santa Rosa', '02510001104', 'Pedido regular', NULL, 5, 1),
(28, 32200771, '2026-03-14 12:16:00.000000', 5, 2, 315.00, 'Calle 54 con Carrera 20', '02514408820', 'Pedido a credito', NULL, 5, 1),
(29, 30333444, '2026-03-16 09:26:00.000000', 5, 2, 390.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido del mes', NULL, 5, 1),
(30, 32200771, '2026-03-18 12:14:00.000000', 5, 2, 470.80, 'Calle 54 con Carrera 20', '02514408820', 'Pedido del mes', 3, 5, 1),
(31, 32200771, '2026-03-19 16:39:00.000000', 5, 2, 840.00, 'Calle 54 con Carrera 20', '02514408820', 'Despacho a tienda', NULL, 5, 1),
(32, 25566582, '2026-03-19 12:13:00.000000', 5, 2, 555.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Pedido del mes', NULL, 5, 1),
(33, 17100998, '2026-03-21 16:19:00.000000', 5, 2, 240.00, 'Av Pedro leon con calle 54', '02511358621', 'Despacho a tienda', NULL, 5, 1),
(34, 30333444, '2026-03-23 11:38:00.000000', 5, 2, 405.00, 'Zona Industrial I, galpon 8', '02510001103', 'Entrega en horario de manana', NULL, 5, 1),
(35, 30666777, '2026-03-23 13:25:00.000000', 5, 2, 400.00, 'Av Venezuela con calle 12', '02510001106', 'Pedido del mes', NULL, 5, 1),
(36, 30111222, '2026-03-27 13:55:00.000000', 5, 2, 595.00, 'Carrera 19 con calle 30', '04120001101', 'Pedido a credito', NULL, 5, 1),
(37, 30444555, '2026-03-30 13:00:00.000000', 5, 2, 710.00, 'Av Principal de Santa Rosa', '02510001104', 'Despacho a tienda', NULL, 5, 1),
(38, 31039811, '2026-03-30 14:29:00.000000', 5, 2, 466.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido regular', 4, 5, 1),
(39, 32200771, '2026-04-02 16:50:00.000000', 5, 2, 675.00, 'Calle 54 con Carrera 20', '02514408820', 'Pedido regular', NULL, 7, 1),
(40, 30555666, '2026-04-04 12:00:00.000000', 5, 2, 585.00, 'Plaza Bolivar, local 2', '04120001105', 'Reposicion de anaqueles', NULL, 7, 1),
(41, 31039811, '2026-04-04 13:59:00.000000', 5, 2, 740.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Entrega en horario de manana', NULL, 7, 1),
(42, 30333444, '2026-04-07 08:18:00.000000', 5, 2, 770.00, 'Zona Industrial I, galpon 8', '02510001103', 'Reposicion de anaqueles', NULL, 7, 1),
(43, 30222333, '2026-04-07 09:58:00.000000', 5, 2, 670.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Pedido regular', NULL, 7, 1),
(44, 17100998, '2026-04-08 08:08:00.000000', 5, 2, 455.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido a credito', NULL, 7, 1),
(45, 30333444, '2026-04-09 16:43:00.000000', 5, 2, 455.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido a credito', NULL, 7, 1),
(46, 30111222, '2026-04-10 16:10:00.000000', 5, 2, 300.00, 'Carrera 19 con calle 30', '04120001101', 'Entrega en horario de manana', NULL, 7, 1),
(47, 31039811, '2026-04-15 14:52:00.000000', 4, 1, 630.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido a credito', NULL, 7, 1),
(48, 31039811, '2026-04-15 08:18:00.000000', 5, 2, 450.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido regular', NULL, 7, 1),
(49, 32200771, '2026-04-16 15:33:00.000000', 4, 1, 195.00, 'Calle 54 con Carrera 20', '02514408820', 'Entrega en horario de manana', NULL, 7, 1),
(50, 25566585, '2026-04-17 12:01:00.000000', 5, 2, 195.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Pedido regular', NULL, 7, 1),
(51, 30333444, '2026-04-17 09:54:00.000000', 5, 2, 610.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido regular', NULL, 7, 1),
(52, 30333444, '2026-04-25 11:21:00.000000', 5, 2, 505.00, 'Zona Industrial I, galpon 8', '02510001103', 'Despacho a tienda', NULL, 7, 1),
(53, 30333444, '2026-04-30 09:44:00.000000', 5, 2, 550.00, 'Zona Industrial I, galpon 8', '02510001103', 'Reposicion de anaqueles', NULL, 7, 1),
(54, 30666777, '2026-05-02 16:16:00.000000', 5, 2, 630.00, 'Av Venezuela con calle 12', '02510001106', 'Pedido del mes', NULL, 9, 1),
(55, 30333444, '2026-05-06 11:12:00.000000', 5, 2, 227.50, 'Zona Industrial I, galpon 8', '02510001103', 'Reposicion de anaqueles', 5, 9, 1),
(56, 17100998, '2026-05-11 12:51:00.000000', 5, 2, 475.00, 'Av Pedro leon con calle 54', '02511358621', 'Entrega en horario de manana', NULL, 9, 1),
(57, 17100998, '2026-05-11 15:40:00.000000', 5, 2, 487.50, 'Av Pedro leon con calle 54', '02511358621', 'Pedido regular', 5, 9, 1),
(58, 30444555, '2026-05-12 09:13:00.000000', 5, 2, 542.50, 'Av Principal de Santa Rosa', '02510001104', 'Despacho a tienda', 5, 9, 1),
(59, 30333444, '2026-05-13 13:18:00.000000', 5, 2, 575.00, 'Zona Industrial I, galpon 8', '02510001103', 'Despacho a tienda', NULL, 9, 1),
(60, 25566585, '2026-05-14 12:48:00.000000', 5, 2, 540.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Pedido a credito', NULL, 9, 1),
(61, 32200771, '2026-05-22 08:01:00.000000', 5, 2, 280.00, 'Calle 54 con Carrera 20', '02514408820', 'Despacho a tienda', NULL, 9, 1),
(62, 30666777, '2026-05-22 16:53:00.000000', 5, 2, 560.00, 'Av Venezuela con calle 12', '02510001106', 'Pedido a credito', NULL, 9, 1),
(63, 30333444, '2026-05-23 13:53:00.000000', 5, 2, 580.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido del mes', NULL, 9, 1),
(64, 17100998, '2026-05-25 08:40:00.000000', 5, 2, 875.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido del mes', NULL, 9, 1),
(65, 17100998, '2026-05-25 16:40:00.000000', 5, 2, 350.00, 'Av Pedro leon con calle 54', '02511358621', 'Entrega en horario de manana', NULL, 9, 1),
(66, 30666777, '2026-05-27 08:27:00.000000', 5, 2, 340.00, 'Av Venezuela con calle 12', '02510001106', 'Pedido a credito', NULL, 9, 1),
(67, 30222333, '2026-05-29 15:25:00.000000', 5, 2, 320.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Pedido regular', NULL, 9, 1),
(68, 31039811, '2026-05-29 11:27:00.000000', 5, 2, 675.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Reposicion de anaqueles', NULL, 9, 1),
(69, 30444555, '2026-05-29 08:07:00.000000', 5, 2, 495.00, 'Av Principal de Santa Rosa', '02510001104', 'Pedido regular', NULL, 9, 1),
(70, 25566582, '2026-06-02 10:52:00.000000', 5, 2, 550.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Reposicion de anaqueles', NULL, 11, 1),
(71, 30666777, '2026-06-04 12:27:00.000000', 5, 2, 650.00, 'Av Venezuela con calle 12', '02510001106', 'Pedido a credito', NULL, 11, 1),
(72, 30444555, '2026-06-05 13:55:00.000000', 5, 2, 515.00, 'Av Principal de Santa Rosa', '02510001104', 'Reposicion de anaqueles', NULL, 11, 1),
(73, 30444555, '2026-06-05 15:16:00.000000', 5, 2, 450.00, 'Av Principal de Santa Rosa', '02510001104', 'Despacho a tienda', NULL, 11, 1),
(74, 31039811, '2026-06-12 11:47:00.000000', 5, 2, 695.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Despacho a tienda', NULL, 11, 1),
(75, 31039811, '2026-06-19 11:59:00.000000', 5, 2, 280.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Despacho a tienda', NULL, 11, 1),
(76, 14555666, '2026-06-19 12:44:00.000000', 5, 2, 375.00, 'Urb Del Este, calle 5', '04120001107', 'Pedido regular', NULL, 11, 1),
(77, 30666777, '2026-06-22 09:48:00.000000', 5, 2, 375.00, 'Av Venezuela con calle 12', '02510001106', 'Pedido a credito', NULL, 11, 1),
(78, 30333444, '2026-06-23 09:44:00.000000', 5, 2, 700.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido del mes', NULL, 11, 1),
(79, 30222333, '2026-06-23 11:20:00.000000', 5, 2, 195.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Entrega en horario de manana', NULL, 11, 1),
(80, 30111222, '2026-06-24 08:43:00.000000', 5, 2, 390.00, 'Carrera 19 con calle 30', '04120001101', 'Despacho a tienda', NULL, 11, 1),
(81, 31039811, '2026-06-25 16:48:00.000000', 5, 2, 635.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido del mes', NULL, 11, 1),
(82, 19888777, '2026-06-25 12:25:00.000000', 5, 2, 180.00, 'Barrio El Jebe, calle 3', '04120001108', 'Pedido regular', NULL, 11, 1),
(83, 32200771, '2026-06-27 16:44:00.000000', 5, 2, 435.00, 'Calle 54 con Carrera 20', '02514408820', 'Pedido regular', NULL, 11, 1),
(84, 30666777, '2026-06-29 08:40:00.000000', 5, 2, 650.00, 'Av Venezuela con calle 12', '02510001106', 'Despacho a tienda', NULL, 11, 1),
(85, 25566585, '2026-06-30 08:37:00.000000', 5, 2, 700.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Pedido regular', NULL, 11, 1),
(86, 30666777, '2026-07-03 11:14:00.000000', 5, 2, 700.00, 'Av Venezuela con calle 12', '02510001106', 'Pedido regular', NULL, 13, 1),
(87, 32200771, '2026-07-07 16:30:00.000000', 5, 2, 700.00, 'Calle 54 con Carrera 20', '02514408820', 'Pedido a credito', NULL, 13, 1),
(88, 30333444, '2026-07-08 14:54:00.000000', 4, 1, 450.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido regular', NULL, 13, 1),
(89, 31039811, '2026-07-09 13:05:00.000000', 5, 2, 360.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido regular', NULL, 13, 1),
(90, 30555666, '2026-07-11 08:03:00.000000', 5, 2, 280.00, 'Plaza Bolivar, local 2', '04120001105', 'Despacho a tienda', NULL, 13, 1),
(91, 30222333, '2026-07-11 14:12:00.000000', 5, 2, 700.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Pedido a credito', NULL, 13, 1),
(92, 14555666, '2026-07-11 13:11:00.000000', 5, 2, 460.00, 'Urb Del Este, calle 5', '04120001107', 'Entrega en horario de manana', NULL, 13, 1),
(93, 32200771, '2026-07-15 08:32:00.000000', 5, 2, 250.00, 'Calle 54 con Carrera 20', '02514408820', 'Pedido del mes', NULL, 13, 1),
(94, 30222333, '2026-07-16 13:50:00.000000', 5, 2, 500.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Pedido a credito', NULL, 13, 1),
(95, 17100998, '2026-07-16 11:38:00.000000', 5, 2, 585.00, 'Av Pedro leon con calle 54', '02511358621', 'Entrega en horario de manana', 6, 13, 1),
(96, 31039811, '2026-07-18 10:31:00.000000', 5, 2, 330.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido del mes', NULL, 13, 1),
(97, 30333444, '2026-07-22 09:08:00.000000', 5, 2, 540.00, 'Zona Industrial I, galpon 8', '02510001103', 'Entrega en horario de manana', NULL, 13, 1),
(98, 30333444, '2026-07-22 14:30:00.000000', 5, 2, 560.00, 'Zona Industrial I, galpon 8', '02510001103', 'Despacho a tienda', NULL, 13, 1),
(99, 30333444, '2026-07-25 11:52:00.000000', 5, 2, 625.00, 'Zona Industrial I, galpon 8', '02510001103', 'Despacho a tienda', NULL, 13, 1),
(100, 31039811, '2026-07-27 13:37:00.000000', 5, 2, 455.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido a credito', NULL, 13, 1),
(101, 30333444, '2026-07-28 09:29:00.000000', 5, 2, 200.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido del mes', NULL, 13, 1),
(102, 30444555, '2026-07-29 14:25:00.000000', 5, 2, 450.00, 'Av Principal de Santa Rosa', '02510001104', 'Reposicion de anaqueles', NULL, 13, 1),
(103, 31039811, '2026-07-31 10:00:00.000000', 4, 1, 515.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Entrega en horario de manana', NULL, 13, 1),
(104, 30333444, '2026-08-05 12:09:00.000000', 5, 2, 420.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido del mes', NULL, 15, 1),
(105, 31039811, '2026-08-07 16:14:00.000000', 5, 2, 500.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Pedido a credito', NULL, 15, 1),
(106, 30666777, '2026-08-07 13:02:00.000000', 5, 2, 375.00, 'Av Venezuela con calle 12', '02510001106', 'Pedido a credito', NULL, 15, 1),
(107, 17100998, '2026-08-08 16:37:00.000000', 5, 2, 360.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido del mes', NULL, 15, 1),
(108, 30555666, '2026-08-10 15:58:00.000000', 5, 2, 735.00, 'Plaza Bolivar, local 2', '04120001105', 'Entrega en horario de manana', NULL, 15, 1),
(109, 31039811, '2026-08-11 10:21:00.000000', 5, 2, 555.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Reposicion de anaqueles', NULL, 15, 1),
(110, 17100998, '2026-08-12 11:41:00.000000', 5, 2, 390.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido a credito', NULL, 15, 1),
(111, 30333444, '2026-08-14 08:41:00.000000', 5, 2, 300.00, 'Zona Industrial I, galpon 8', '02510001103', 'Entrega en horario de manana', NULL, 15, 1),
(112, 30555666, '2026-08-15 10:06:00.000000', 5, 2, 565.00, 'Plaza Bolivar, local 2', '04120001105', 'Reposicion de anaqueles', NULL, 15, 1),
(113, 30333444, '2026-08-18 08:10:00.000000', 5, 2, 420.00, 'Zona Industrial I, galpon 8', '02510001103', 'Reposicion de anaqueles', NULL, 15, 1),
(114, 19888777, '2026-08-19 13:13:00.000000', 5, 2, 520.00, 'Barrio El Jebe, calle 3', '04120001108', 'Despacho a tienda', NULL, 15, 1),
(115, 30111222, '2026-08-20 13:02:00.000000', 5, 2, 240.00, 'Carrera 19 con calle 30', '04120001101', 'Pedido regular', NULL, 15, 1),
(116, 17100998, '2026-08-22 08:27:00.000000', 5, 2, 805.00, 'Av Pedro leon con calle 54', '02511358621', 'Reposicion de anaqueles', NULL, 15, 1),
(117, 30111222, '2026-08-22 15:04:00.000000', 5, 2, 745.00, 'Carrera 19 con calle 30', '04120001101', 'Pedido del mes', NULL, 15, 1),
(118, 17100998, '2026-08-24 13:04:00.000000', 5, 2, 610.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido a credito', NULL, 15, 1),
(119, 30333444, '2026-08-28 14:34:00.000000', 5, 2, 840.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido regular', NULL, 15, 1),
(120, 30333444, '2026-08-31 09:02:00.000000', 5, 2, 490.00, 'Zona Industrial I, galpon 8', '02510001103', 'Reposicion de anaqueles', NULL, 15, 1),
(121, 30444555, '2026-08-31 10:06:00.000000', 5, 2, 430.00, 'Av Principal de Santa Rosa', '02510001104', 'Despacho a tienda', NULL, 15, 1),
(122, 31039811, '2026-09-02 16:57:00.000000', 5, 2, 470.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Reposicion de anaqueles', NULL, 17, 1),
(123, 30666777, '2026-09-03 12:07:00.000000', 4, 1, 275.00, 'Av Venezuela con calle 12', '02510001106', 'Entrega en horario de manana', NULL, 17, 1),
(124, 32200771, '2026-09-05 11:32:00.000000', 5, 2, 315.00, 'Calle 54 con Carrera 20', '02514408820', 'Pedido a credito', NULL, 17, 1),
(125, 30222333, '2026-09-07 09:57:00.000000', 5, 2, 455.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Pedido del mes', 7, 17, 1),
(126, 30666777, '2026-09-07 16:56:00.000000', 5, 2, 575.00, 'Av Venezuela con calle 12', '02510001106', 'Pedido del mes', NULL, 17, 1),
(127, 25566580, '2026-09-07 14:02:00.000000', 5, 2, 595.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Despacho a tienda', NULL, 17, 1),
(128, 30333444, '2026-09-08 14:33:00.000000', 5, 2, 735.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido del mes', NULL, 17, 1),
(129, 17100998, '2026-09-09 15:27:00.000000', 5, 2, 600.00, 'Av Pedro leon con calle 54', '02511358621', 'Despacho a tienda', NULL, 17, 1),
(130, 30555666, '2026-09-11 15:19:00.000000', 5, 2, 735.00, 'Plaza Bolivar, local 2', '04120001105', 'Despacho a tienda', NULL, 17, 1),
(131, 17100998, '2026-09-15 15:05:00.000000', 5, 2, 455.00, 'Av Pedro leon con calle 54', '02511358621', 'Reposicion de anaqueles', NULL, 17, 1),
(132, 30444555, '2026-09-16 13:01:00.000000', 5, 2, 375.00, 'Av Principal de Santa Rosa', '02510001104', 'Despacho a tienda', NULL, 17, 1),
(133, 17100998, '2026-09-17 08:21:00.000000', 5, 2, 400.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido a credito', NULL, 17, 1),
(134, 30666777, '2026-09-17 10:24:00.000000', 5, 2, 405.00, 'Av Venezuela con calle 12', '02510001106', 'Entrega en horario de manana', NULL, 17, 1),
(135, 14555666, '2026-09-21 14:18:00.000000', 5, 2, 541.00, 'Urb Del Este, calle 5', '04120001107', 'Despacho a tienda', 7, 17, 1),
(136, 30111222, '2026-09-24 08:56:00.000000', 5, 2, 500.00, 'Carrera 19 con calle 30', '04120001101', 'Reposicion de anaqueles', NULL, 17, 1),
(137, 17100998, '2026-09-29 10:52:00.000000', 5, 2, 425.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido a credito', NULL, 17, 1),
(138, 17100998, '2026-10-02 16:37:00.000000', 5, 2, 325.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido a credito', NULL, 19, 1),
(139, 32200771, '2026-10-05 15:35:00.000000', 5, 2, 675.00, 'Calle 54 con Carrera 20', '02514408820', 'Entrega en horario de manana', NULL, 19, 1),
(140, 30222333, '2026-10-09 10:02:00.000000', 5, 2, 280.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Entrega en horario de manana', NULL, 19, 1),
(141, 17100998, '2026-10-10 11:46:00.000000', 5, 2, 225.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido del mes', NULL, 19, 1),
(142, 30111222, '2026-10-12 16:38:00.000000', 5, 2, 165.00, 'Carrera 19 con calle 30', '04120001101', 'Pedido a credito', NULL, 19, 1),
(143, 17100998, '2026-10-12 10:10:00.000000', 4, 1, 382.50, 'Av Pedro leon con calle 54', '02511358621', 'Pedido regular', 8, 19, 1),
(144, 32200771, '2026-10-15 14:39:00.000000', 4, 1, 425.00, 'Calle 54 con Carrera 20', '02514408820', 'Reposicion de anaqueles', NULL, 19, 1),
(145, 32200771, '2026-10-15 10:31:00.000000', 5, 2, 525.00, 'Calle 54 con Carrera 20', '02514408820', 'Entrega en horario de manana', NULL, 19, 1),
(146, 25566585, '2026-10-17 10:17:00.000000', 4, 1, 400.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Despacho a tienda', NULL, 19, 1),
(147, 30444555, '2026-10-17 15:17:00.000000', 4, 1, 675.00, 'Av Principal de Santa Rosa', '02510001104', 'Pedido a credito', NULL, 19, 1),
(148, 17100998, '2026-10-20 09:27:00.000000', 5, 2, 275.00, 'Av Pedro leon con calle 54', '02511358621', 'Pedido del mes', NULL, 19, 1),
(149, 30111222, '2026-10-20 12:05:00.000000', 5, 2, 340.00, 'Carrera 19 con calle 30', '04120001101', 'Pedido del mes', NULL, 19, 1),
(150, 30666777, '2026-10-20 14:28:00.000000', 5, 2, 460.00, 'Av Venezuela con calle 12', '02510001106', 'Reposicion de anaqueles', NULL, 19, 1),
(151, 30666777, '2026-10-22 08:51:00.000000', 5, 2, 385.00, 'Av Venezuela con calle 12', '02510001106', 'Reposicion de anaqueles', 8, 19, 1),
(152, 30111222, '2026-10-22 14:32:00.000000', 5, 2, 630.00, 'Carrera 19 con calle 30', '04120001101', 'Pedido a credito', NULL, 19, 1),
(153, 30222333, '2026-10-27 11:33:00.000000', 4, 1, 325.00, 'Calle 42 entre carreras 25 y 26', '04120001102', 'Reposicion de anaqueles', NULL, 19, 1),
(154, 30444555, '2026-10-30 12:47:00.000000', 4, 1, 250.00, 'Av Principal de Santa Rosa', '02510001104', 'Pedido a credito', NULL, 19, 1),
(155, 25566585, '2026-10-31 10:40:00.000000', 4, 1, 300.00, 'Urb Eligio Macias Mujica Calle 3', '04122373562', 'Pedido del mes', NULL, 19, 1),
(156, 30555666, '2026-11-03 10:03:00.000000', 5, 2, 535.00, 'Plaza Bolivar, local 2', '04120001105', 'Pedido a credito', NULL, 21, 1),
(157, 30333444, '2026-11-04 16:12:00.000000', 3, 1, 650.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido a credito', NULL, 21, 1),
(158, 30333444, '2026-11-04 10:27:00.000000', 3, 2, 437.50, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido regular', 9, 21, 1),
(159, 17100998, '2026-11-06 09:04:00.000000', 2, 1, 365.00, 'Av Pedro leon con calle 54', '02511358621', 'Despacho a tienda', NULL, 21, 1),
(160, 31039811, '2026-11-09 14:02:00.000000', 1, 1, 430.00, 'Av Urb Patarata con Calle 20', '02513213495', 'Entrega en horario de manana', NULL, 23, 1),
(161, 30333444, '2026-11-09 13:53:00.000000', 1, 1, 650.00, 'Zona Industrial I, galpon 8', '02510001103', 'Pedido del mes', NULL, 23, 1),
(162, 33220449, '2026-11-17 00:00:00.000000', 1, 2, 545.00, 'Av libertador calle 33', '04123454589', 'Delivery incluido', NULL, 23, 0);

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
(1, 1, 1300, '2026-01-02', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(2, 2, 500, '2026-01-02', 'Produccion mensual', 'Lote de galletas de coco', 1),
(3, 3, 600, '2026-01-02', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(4, 4, 1300, '2026-01-02', 'Produccion mensual', 'Lote de galletas de colita', 1),
(5, 5, 600, '2026-01-02', 'Produccion mensual', 'Lote de galletas de limon', 1),
(6, 1, 600, '2026-02-02', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(7, 2, 200, '2026-02-02', 'Produccion mensual', 'Lote de galletas de coco', 1),
(8, 3, 400, '2026-02-02', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(9, 4, 1200, '2026-02-02', 'Produccion mensual', 'Lote de galletas de colita', 1),
(10, 5, 200, '2026-02-02', 'Produccion mensual', 'Lote de galletas de limon', 1),
(11, 1, 1200, '2026-03-02', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(12, 2, 600, '2026-03-02', 'Produccion mensual', 'Lote de galletas de coco', 1),
(13, 3, 400, '2026-03-02', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(14, 4, 500, '2026-03-02', 'Produccion mensual', 'Lote de galletas de colita', 1),
(15, 5, 600, '2026-03-02', 'Produccion mensual', 'Lote de galletas de limon', 1),
(16, 1, 500, '2026-04-01', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(17, 2, 900, '2026-04-01', 'Produccion mensual', 'Lote de galletas de coco', 1),
(18, 3, 100, '2026-04-01', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(19, 4, 600, '2026-04-01', 'Produccion mensual', 'Lote de galletas de colita', 1),
(20, 5, 800, '2026-04-01', 'Produccion mensual', 'Lote de galletas de limon', 1),
(21, 1, 200, '2026-05-01', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(22, 2, 900, '2026-05-01', 'Produccion mensual', 'Lote de galletas de coco', 1),
(23, 3, 1300, '2026-05-01', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(24, 4, 300, '2026-05-01', 'Produccion mensual', 'Lote de galletas de colita', 1),
(25, 5, 900, '2026-05-01', 'Produccion mensual', 'Lote de galletas de limon', 1),
(26, 1, 700, '2026-06-01', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(27, 2, 400, '2026-06-01', 'Produccion mensual', 'Lote de galletas de coco', 1),
(28, 3, 400, '2026-06-01', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(29, 4, 300, '2026-06-01', 'Produccion mensual', 'Lote de galletas de colita', 1),
(30, 5, 1100, '2026-06-01', 'Produccion mensual', 'Lote de galletas de limon', 1),
(31, 1, 500, '2026-07-01', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(32, 2, 600, '2026-07-01', 'Produccion mensual', 'Lote de galletas de coco', 1),
(33, 3, 1100, '2026-07-01', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(34, 4, 1400, '2026-07-01', 'Produccion mensual', 'Lote de galletas de colita', 1),
(35, 5, 400, '2026-07-01', 'Produccion mensual', 'Lote de galletas de limon', 1),
(36, 1, 900, '2026-08-01', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(37, 2, 800, '2026-08-01', 'Produccion mensual', 'Lote de galletas de coco', 1),
(38, 3, 1300, '2026-08-01', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(39, 4, 100, '2026-08-01', 'Produccion mensual', 'Lote de galletas de colita', 1),
(40, 5, 800, '2026-08-01', 'Produccion mensual', 'Lote de galletas de limon', 1),
(41, 1, 500, '2026-09-01', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(42, 2, 800, '2026-09-01', 'Produccion mensual', 'Lote de galletas de coco', 1),
(43, 3, 700, '2026-09-01', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(44, 4, 800, '2026-09-01', 'Produccion mensual', 'Lote de galletas de colita', 1),
(45, 5, 600, '2026-09-01', 'Produccion mensual', 'Lote de galletas de limon', 1),
(46, 1, 500, '2026-10-01', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(47, 3, 1000, '2026-10-01', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(48, 4, 1000, '2026-10-01', 'Produccion mensual', 'Lote de galletas de colita', 1),
(49, 5, 400, '2026-10-01', 'Produccion mensual', 'Lote de galletas de limon', 1),
(50, 1, 500, '2026-11-02', 'Produccion mensual', 'Lote de galletas de naranja', 1),
(51, 2, 200, '2026-11-02', 'Produccion mensual', 'Lote de galletas de coco', 1),
(52, 3, 100, '2026-11-02', 'Produccion mensual', 'Lote de galletas de queso cheddar', 1),
(53, 4, 400, '2026-11-02', 'Produccion mensual', 'Lote de galletas de colita', 1),
(54, 5, 500, '2026-11-02', 'Produccion mensual', 'Lote de galletas de limon', 1);

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
  `status` int(11) NOT NULL DEFAULT 1,
  `visibilidad_ecommerce` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`id_producto`, `nombre_producto`, `precio_venta`, `stock`, `fecha_registro`, `fecha_vencimiento`, `id_categoria`, `imagen`, `status`, `visibilidad_ecommerce`) VALUES
(1, 'Galletas Natys dulces con sabor a Naranja 90g', 1.50, 330, '2026-01-02', '2027-05-31', 1, 'assets/img/productos/img6.png', 1, 1),
(2, 'Galletas dulces Natys con sabor a coco 90g', 3.50, 230, '2026-01-02', '2027-05-31', 1, 'assets/img/productos/img1.png', 1, 1),
(3, 'Galletas Natys Saladitas queso chedar 90g', 2.00, 270, '2026-01-02', '2027-05-31', 2, 'assets/img/productos/img3.png', 1, 1),
(4, 'Galletas Natys dulces con sabor a Colita 90g', 2.50, 240, '2026-01-02', '2027-05-31', 1, 'assets/img/productos/img4.png', 1, 1),
(5, 'Galletas Natys dulces con sabor a Limon 90g', 2.50, 270, '2026-01-02', '2027-05-31', 1, 'assets/img/productos/emp_limon-BKkbFTo6.png', 1, 1);

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
(1, 'Inicio de ano naranja', 'Descuento de enero', '2026-01-12', '2026-01-31', 'porcentaje', 10.00, 0, 1),
(2, '2x1 Carnaval coco', 'Promocion de carnaval', '2026-02-09', '2026-02-18', '2x1', 2.00, 0, 1),
(3, 'Marzo salado', 'Descuento en cheddar', '2026-03-09', '2026-03-21', 'porcentaje', 8.00, 0, 1),
(4, 'Semana Santa colita', 'Descuento de temporada', '2026-03-30', '2026-04-11', 'porcentaje', 12.00, 0, 1),
(5, 'Mes de las madres', '2x1 en coco', '2026-05-04', '2026-05-16', '2x1', 2.00, 0, 1),
(6, 'Vacaciones limon', 'Descuento de vacaciones', '2026-07-13', '2026-07-31', 'porcentaje', 10.00, 0, 1),
(7, 'Regreso a clases', 'Descuento en cheddar', '2026-09-07', '2026-09-26', 'porcentaje', 10.00, 0, 1),
(8, 'Octubre naranja', '2x1 en naranja', '2026-10-12', '2026-10-24', '2x1', 2.00, 0, 1),
(9, '2x1 en galletas de coco', 'Promocion de noviembre', '2026-11-01', '2026-11-30', '2x1', 2.00, 1, 1),
(10, '10% en galletas de colita', 'Descuento de noviembre', '2026-11-05', '2026-11-20', 'porcentaje', 10.00, 1, 1);

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
  `fecha_registro` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `proveedores`
--

INSERT INTO `proveedores` (`id_proveedor`, `tipo_id`, `nombre_proveedor`, `direccion_proveedor`, `tlf_proveedor`, `email_proveedor`, `fecha_registro`, `status`) VALUES
(12321234, 'J', 'Empresas Polar CA', 'Zona industrial II calle 1', '02513213490', 'polar_lara@gmail.com', '2026-01-02 08:00:00.000000', 1),
(17100998, 'J-', 'Alimentos Lara CA', 'Zona industrial II calle 4', '02514408820', 'alimentoslara@gmail.com', '2026-01-02 08:00:00.000000', 1),
(23412678, 'J', 'Alimentos Mary ca', 'Carrera 4 calle 2 zonal industrial 3', '02512345478', 'mary@gmail.com', '2026-11-17 15:10:09.685134', 1),
(24634215, 'J', 'Arichuna', 'Carrera 21 con calle 29 y 39', '02513213499', 'arichuna@gmail.com', '2026-01-02 08:00:00.000000', 1),
(31039711, 'J-', 'Distribuidor la 21ca', 'Carrera 21 con calle 29', '02513213495', 'Dis21ca@gmail.com', '2026-01-02 08:00:00.000000', 1),
(87576857, 'J', 'La Capri ca', 'Zona industrial II calle 4', '02513213433', 'capri@gmai.com', '2026-01-02 08:00:00.000000', 1),
(478475938, 'J-', 'La FRIZ', 'Carrera 21 con calle 29', '02513213495', 'friz@gmail.com', '2026-01-02 08:00:00.000000', 1),
(987234923, 'J-', 'La especial ca', 'Carrera 21 con calle 29 y 30', '02513213495', 'Laespecial@gmail.com', '2026-01-02 08:00:00.000000', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tasa_dia`
--

CREATE TABLE `tasa_dia` (
  `id_tasa` int(11) NOT NULL,
  `id_moneda` int(11) NOT NULL,
  `monto_tasa` float(11,2) NOT NULL,
  `fecha_tasa` datetime(6) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `tasa_dia`
--

INSERT INTO `tasa_dia` (`id_tasa`, `id_moneda`, `monto_tasa`, `fecha_tasa`, `status`) VALUES
(1, 1, 340.00, '2026-01-02 08:00:00.000000', 1),
(2, 2, 442.00, '2026-01-02 08:05:00.000000', 1),
(3, 1, 372.00, '2026-02-02 08:00:00.000000', 1),
(4, 2, 483.60, '2026-02-02 08:05:00.000000', 1),
(5, 1, 410.00, '2026-03-02 08:00:00.000000', 1),
(6, 2, 533.00, '2026-03-02 08:05:00.000000', 1),
(7, 1, 455.00, '2026-04-01 08:00:00.000000', 1),
(8, 2, 591.50, '2026-04-01 08:05:00.000000', 1),
(9, 1, 520.00, '2026-05-01 08:00:00.000000', 1),
(10, 2, 676.00, '2026-05-01 08:05:00.000000', 1),
(11, 1, 596.79, '2026-06-01 08:00:00.000000', 1),
(12, 2, 797.75, '2026-06-01 08:05:00.000000', 1),
(13, 1, 640.00, '2026-07-01 08:00:00.000000', 1),
(14, 2, 832.00, '2026-07-01 08:05:00.000000', 1),
(15, 1, 690.00, '2026-08-01 08:00:00.000000', 1),
(16, 2, 897.00, '2026-08-01 08:05:00.000000', 1),
(17, 1, 745.00, '2026-09-01 08:00:00.000000', 1),
(18, 2, 968.50, '2026-09-01 08:05:00.000000', 1),
(19, 1, 805.00, '2026-10-01 08:00:00.000000', 1),
(20, 2, 1046.50, '2026-10-01 08:05:00.000000', 1),
(21, 1, 870.00, '2026-11-02 08:00:00.000000', 1),
(22, 2, 1131.00, '2026-11-02 08:05:00.000000', 1),
(23, 1, 905.00, '2026-11-09 08:00:00.000000', 1);

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
  `nombre_medida` varchar(100) NOT NULL,
  `descripcion_medida` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `unidad_medidas`
--

INSERT INTO `unidad_medidas` (`id_unidad_medida`, `nombre_medida`, `descripcion_medida`, `status`) VALUES
(1, 'Sacos', 'medicion de sacos ', 1),
(2, 'Bultos', 'medicion de bultos ', 1),
(3, 'Kilogramos', 'medicion en kilogramos', 1),
(4, 'Litros', 'medicion en litros', 1),
(5, 'Cajas', 'medicion en cajas', 1),
(6, 'Galon', 'Para la medicion en galones', 1),
(7, 'Gramos', 'para cantidades menores', 1),
(8, 'Tanque', 'para volumen de litros', 1),
(9, 'rag', 'para mas', 1);

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
-- Estructura Stand-in para la vista `vista_compras_proveedores_totales`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_compras_proveedores_totales` (
`id_proveedor` int(11)
,`nombre_proveedor` varchar(100)
,`total_compras` bigint(21)
,`monto_total_invertido` double(19,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_cuentas_por_cobrar_pendientes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_cuentas_por_cobrar_pendientes` (
`id_cuenta_x_cobrar` int(11)
,`nombre_cliente` varchar(100)
,`tlf_cliente` varchar(11)
,`id_pedido` int(11)
,`monto_total` float(11,2)
,`saldo_pendiente` float(11,2)
,`fecha_vencimiento` date
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_estado_despachos_entregas`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_estado_despachos_entregas` (
`id_entregas` int(11)
,`repartidor` varchar(200)
,`estado_despacho` varchar(100)
,`id_pedido` int(11)
,`nombre_cliente` varchar(100)
,`fecha_entrega_programada` date
,`fecha_entrega_real` date
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_materia_prima_critica`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_materia_prima_critica` (
`id_materia_prima` int(11)
,`nombre_materia_prima` varchar(100)
,`stock_actual` int(11)
,`nombre_medida` varchar(100)
,`nombre_proveedor` varchar(100)
,`tlf_proveedor` varchar(11)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_rendimiento_productos_top`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_rendimiento_productos_top` (
`id_producto` int(11)
,`nombre_producto` varchar(100)
,`nombre_categoria` varchar(100)
,`total_unidades_vendidas` decimal(32,0)
,`ingresos_generados` double(19,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_resumen_ventas_cliente`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_resumen_ventas_cliente` (
`id_cliente` int(11)
,`nombre_cliente` varchar(100)
,`total_pedidos` bigint(21)
,`total_comprado` double(19,2)
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
-- Estructura para la vista `vista_compras_proveedores_totales`
--
DROP TABLE IF EXISTS `vista_compras_proveedores_totales`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_compras_proveedores_totales`  AS SELECT `pr`.`id_proveedor` AS `id_proveedor`, `pr`.`nombre_proveedor` AS `nombre_proveedor`, count(`co`.`id_compra`) AS `total_compras`, coalesce(sum(`co`.`monto_total_compra`),0) AS `monto_total_invertido` FROM (`proveedores` `pr` left join `compras` `co` on(`pr`.`id_proveedor` = `co`.`id_proveedor` and `co`.`status` = 1)) GROUP BY `pr`.`id_proveedor`, `pr`.`nombre_proveedor` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_cuentas_por_cobrar_pendientes`
--
DROP TABLE IF EXISTS `vista_cuentas_por_cobrar_pendientes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_cuentas_por_cobrar_pendientes`  AS SELECT `cxc`.`id_cuenta_x_cobrar` AS `id_cuenta_x_cobrar`, `c`.`nombre_cliente` AS `nombre_cliente`, `c`.`tlf_cliente` AS `tlf_cliente`, `cxc`.`id_pedido` AS `id_pedido`, `cxc`.`monto_total` AS `monto_total`, `cxc`.`saldo_pendiente` AS `saldo_pendiente`, `cxc`.`fecha_vencimiento` AS `fecha_vencimiento` FROM (`cuenta_x_cobrar` `cxc` join `clientes` `c` on(`cxc`.`id_cliente` = `c`.`id_cliente`)) WHERE `cxc`.`estado_cuenta` = 'Por Pagar' AND `cxc`.`status` = 1 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_estado_despachos_entregas`
--
DROP TABLE IF EXISTS `vista_estado_despachos_entregas`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_estado_despachos_entregas`  AS SELECT `e`.`id_entregas` AS `id_entregas`, `e`.`repartidor` AS `repartidor`, `ee`.`nombre_estado` AS `estado_despacho`, `p`.`id_pedido` AS `id_pedido`, `c`.`nombre_cliente` AS `nombre_cliente`, `e`.`fecha_entrega_programada` AS `fecha_entrega_programada`, `e`.`fecha_entrega_real` AS `fecha_entrega_real` FROM (((`entregas` `e` join `estado_entrega` `ee` on(`e`.`id_estado_entrega` = `ee`.`id_estado_entrega`)) join `pedidos` `p` on(`e`.`id_pedido` = `p`.`id_pedido`)) join `clientes` `c` on(`p`.`id_cliente` = `c`.`id_cliente`)) WHERE `e`.`status` = 1 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_materia_prima_critica`
--
DROP TABLE IF EXISTS `vista_materia_prima_critica`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_materia_prima_critica`  AS SELECT `mp`.`id_materia_prima` AS `id_materia_prima`, `mp`.`nombre_materia_prima` AS `nombre_materia_prima`, `mp`.`stock_actual` AS `stock_actual`, `um`.`nombre_medida` AS `nombre_medida`, `pr`.`nombre_proveedor` AS `nombre_proveedor`, `pr`.`tlf_proveedor` AS `tlf_proveedor` FROM ((`materia_prima` `mp` join `unidad_medidas` `um` on(`mp`.`id_unidad_medida` = `um`.`id_unidad_medida`)) join `proveedores` `pr` on(`mp`.`id_proveedor` = `pr`.`id_proveedor`)) WHERE `mp`.`stock_actual` < 30 AND `mp`.`status` = 1 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_rendimiento_productos_top`
--
DROP TABLE IF EXISTS `vista_rendimiento_productos_top`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_rendimiento_productos_top`  AS SELECT `pr`.`id_producto` AS `id_producto`, `pr`.`nombre_producto` AS `nombre_producto`, `cat`.`nombre_categoria` AS `nombre_categoria`, coalesce(sum(`dp`.`cantidad`),0) AS `total_unidades_vendidas`, coalesce(sum(`dp`.`cantidad` * `dp`.`precio_unitario`),0) AS `ingresos_generados` FROM ((`productos` `pr` join `categorias` `cat` on(`pr`.`id_categoria` = `cat`.`id_categoria`)) left join `detalle_pedidos` `dp` on(`pr`.`id_producto` = `dp`.`id_producto`)) GROUP BY `pr`.`id_producto`, `pr`.`nombre_producto`, `cat`.`nombre_categoria` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_resumen_ventas_cliente`
--
DROP TABLE IF EXISTS `vista_resumen_ventas_cliente`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_resumen_ventas_cliente`  AS SELECT `c`.`id_cliente` AS `id_cliente`, `c`.`nombre_cliente` AS `nombre_cliente`, count(`p`.`id_pedido`) AS `total_pedidos`, coalesce(sum(`p`.`monto_total_pedido`),0) AS `total_comprado` FROM (`clientes` `c` left join `pedidos` `p` on(`c`.`id_cliente` = `p`.`id_cliente` and `p`.`status` = 1)) GROUP BY `c`.`id_cliente`, `c`.`nombre_cliente` ;

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
-- Indices de la tabla `camiones`
--
ALTER TABLE `camiones`
  ADD PRIMARY KEY (`id_camion`),
  ADD UNIQUE KEY `uq_placa` (`placa`);

--
-- Indices de la tabla `carrito`
--
ALTER TABLE `carrito`
  ADD PRIMARY KEY (`id_carrito`),
  ADD KEY `idx_carrito_usuario_estado` (`id_usuario`,`estado`);

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
  ADD KEY `id_estado_pago` (`id_estado_pago`),
  ADD KEY `idx_compras_proveedor_fecha` (`id_proveedor`,`fecha_compra`);

--
-- Indices de la tabla `cuenta_x_cobrar`
--
ALTER TABLE `cuenta_x_cobrar`
  ADD PRIMARY KEY (`id_cuenta_x_cobrar`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_cliente` (`id_cliente`),
  ADD KEY `idx_cuentas_estado_vencimiento` (`estado_cuenta`,`fecha_vencimiento`);

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
-- Indices de la tabla `detalle_carrito`
--
ALTER TABLE `detalle_carrito`
  ADD PRIMARY KEY (`id_detalle_carrito`),
  ADD KEY `id_carrito` (`id_carrito`),
  ADD KEY `id_producto` (`id_producto`);

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
  ADD KEY `id_producto` (`id_producto`),
  ADD KEY `idx_detalle_pedidos_producto` (`id_producto`);

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
  ADD KEY `fecha_entrega_programada` (`fecha_entrega_programada`),
  ADD KEY `idx_entregas_estado_pedido` (`id_estado_entrega`,`id_pedido`),
  ADD KEY `id_camion` (`id_camion`);

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
  ADD KEY `id_proveedor` (`id_proveedor`),
  ADD KEY `idx_materia_prima_stock` (`stock_actual`);

--
-- Indices de la tabla `metodos_pago`
--
ALTER TABLE `metodos_pago`
  ADD PRIMARY KEY (`id_metodo_pago`);

--
-- Indices de la tabla `monedas`
--
ALTER TABLE `monedas`
  ADD PRIMARY KEY (`id_moneda`);

--
-- Indices de la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD PRIMARY KEY (`id_pago`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_metodo_pago` (`id_metodo_pago`),
  ADD KEY `idx_pagos_pedido_fecha` (`id_pedido`,`fecha_pago`);

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
  ADD KEY `fecha_pedido` (`fecha_pedido`),
  ADD KEY `idx_pedidos_cliente_fecha` (`id_cliente`,`fecha_pedido`);

--
-- Indices de la tabla `producciones`
--
ALTER TABLE `producciones`
  ADD PRIMARY KEY (`id_produccion`),
  ADD KEY `id_producto` (`id_producto`),
  ADD KEY `idx_producciones_producto_fecha` (`id_producto`,`fecha_produccion`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id_producto`),
  ADD KEY `id_categoria` (`id_categoria`),
  ADD KEY `idx_productos_categoria_status` (`id_categoria`,`status`);

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
  ADD PRIMARY KEY (`id_tasa`),
  ADD KEY `id_moneda` (`id_moneda`);

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
-- AUTO_INCREMENT de la tabla `camiones`
--
ALTER TABLE `camiones`
  MODIFY `id_camion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT de la tabla `carrito`
--
ALTER TABLE `carrito`
  MODIFY `id_carrito` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `categorias`
--
ALTER TABLE `categorias`
  MODIFY `id_categoria` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=54;

--
-- AUTO_INCREMENT de la tabla `clientes`
--
ALTER TABLE `clientes`
  MODIFY `id_cliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2147483648;

--
-- AUTO_INCREMENT de la tabla `compras`
--
ALTER TABLE `compras`
  MODIFY `id_compra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT de la tabla `cuenta_x_cobrar`
--
ALTER TABLE `cuenta_x_cobrar`
  MODIFY `id_cuenta_x_cobrar` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=163;

--
-- AUTO_INCREMENT de la tabla `cuenta_x_pagar`
--
ALTER TABLE `cuenta_x_pagar`
  MODIFY `id_cuenta_x_pagar` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT de la tabla `detalles_entregas`
--
ALTER TABLE `detalles_entregas`
  MODIFY `id_detalle_entrega` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=501;

--
-- AUTO_INCREMENT de la tabla `detalle_carrito`
--
ALTER TABLE `detalle_carrito`
  MODIFY `id_detalle_carrito` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  MODIFY `id_detalle_compra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=185;

--
-- AUTO_INCREMENT de la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  MODIFY `id_detalle_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=794;

--
-- AUTO_INCREMENT de la tabla `detalle_producciones`
--
ALTER TABLE `detalle_producciones`
  MODIFY `id_detalle_produccion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=705;

--
-- AUTO_INCREMENT de la tabla `detalle_promocion`
--
ALTER TABLE `detalle_promocion`
  MODIFY `id_detalle_promocion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=85;

--
-- AUTO_INCREMENT de la tabla `entregas`
--
ALTER TABLE `entregas`
  MODIFY `id_entregas` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=159;

--
-- AUTO_INCREMENT de la tabla `entrega_pedidos`
--
ALTER TABLE `entrega_pedidos`
  MODIFY `id_entrega_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=492;

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
  MODIFY `id_materia_prima` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT de la tabla `metodos_pago`
--
ALTER TABLE `metodos_pago`
  MODIFY `id_metodo_pago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `monedas`
--
ALTER TABLE `monedas`
  MODIFY `id_moneda` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT de la tabla `pagos`
--
ALTER TABLE `pagos`
  MODIFY `id_pago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=481;

--
-- AUTO_INCREMENT de la tabla `pagos_proveedores`
--
ALTER TABLE `pagos_proveedores`
  MODIFY `id_pago_proveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=99;

--
-- AUTO_INCREMENT de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  MODIFY `id_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=163;

--
-- AUTO_INCREMENT de la tabla `producciones`
--
ALTER TABLE `producciones`
  MODIFY `id_produccion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=55;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT de la tabla `promociones`
--
ALTER TABLE `promociones`
  MODIFY `id_promocion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  MODIFY `id_proveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=987234924;

--
-- AUTO_INCREMENT de la tabla `tasa_dia`
--
ALTER TABLE `tasa_dia`
  MODIFY `id_tasa` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT de la tabla `tipos_clientes`
--
ALTER TABLE `tipos_clientes`
  MODIFY `id_tipo_cliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT de la tabla `unidad_medidas`
--
ALTER TABLE `unidad_medidas`
  MODIFY `id_unidad_medida` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

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
  ADD CONSTRAINT `compras_ibfk_1` FOREIGN KEY (`id_proveedor`) REFERENCES `proveedores` (`id_proveedor`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `cuenta_x_cobrar`
--
ALTER TABLE `cuenta_x_cobrar`
  ADD CONSTRAINT `cuenta_x_cobrar_ibfk_2` FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id_cliente`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `cuenta_x_pagar`
--
ALTER TABLE `cuenta_x_pagar`
  ADD CONSTRAINT `cuenta_x_pagar_ibfk_1` FOREIGN KEY (`id_compra`) REFERENCES `compras` (`id_compra`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalles_entregas`
--
ALTER TABLE `detalles_entregas`
  ADD CONSTRAINT `detalles_entregas_ibfk_1` FOREIGN KEY (`id_entrega`) REFERENCES `entregas` (`id_entregas`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalles_entregas_ibfk_2` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_carrito`
--
ALTER TABLE `detalle_carrito`
  ADD CONSTRAINT `detalle_carrito_ibfk_1` FOREIGN KEY (`id_carrito`) REFERENCES `carrito` (`id_carrito`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detalle_carrito_ibfk_2` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

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
  ADD CONSTRAINT `entregas_ibfk_1` FOREIGN KEY (`id_estado_entrega`) REFERENCES `estado_entrega` (`id_estado_entrega`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `entregas_ibfk_2` FOREIGN KEY (`id_camion`) REFERENCES `camiones` (`id_camion`);

--
-- Filtros para la tabla `materia_prima`
--
ALTER TABLE `materia_prima`
  ADD CONSTRAINT `materia_prima_ibfk_1` FOREIGN KEY (`id_unidad_medida`) REFERENCES `unidad_medidas` (`id_unidad_medida`) ON DELETE CASCADE ON UPDATE CASCADE;

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
  ADD CONSTRAINT `pagos_proveedores_ibfk_1` FOREIGN KEY (`id_cuenta_x_pagar`) REFERENCES `cuenta_x_pagar` (`id_cuenta_x_pagar`) ON DELETE CASCADE ON UPDATE CASCADE;

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

--
-- Filtros para la tabla `tasa_dia`
--
ALTER TABLE `tasa_dia`
  ADD CONSTRAINT `tasa_dia_ibfk_1` FOREIGN KEY (`id_moneda`) REFERENCES `monedas` (`id_moneda`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
