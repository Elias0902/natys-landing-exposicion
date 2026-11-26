-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 18-11-2026 a las 22:51:31
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
-- Base de datos: `larence_seguridad`
--

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `accesos`
--

CREATE TABLE `accesos` (
  `id_accesos` int(11) NOT NULL,
  `id_rol` int(11) NOT NULL,
  `id_modulo` int(11) NOT NULL,
  `id_permiso` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `bitacoras`
--

CREATE TABLE `bitacoras` (
  `id_bitacora` int(11) NOT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `modulo` varchar(100) NOT NULL,
  `accion` varchar(100) NOT NULL,
  `descripcion` varchar(500) NOT NULL,
  `fecha_bitacora` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `conversaciones_ia`
--

CREATE TABLE `conversaciones_ia` (
  `id_conversacion` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `fecha_inicio` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `mensajes_ia`
--

CREATE TABLE `mensajes_ia` (
  `id_mensaje` int(11) NOT NULL,
  `id_conversacion` int(11) NOT NULL,
  `emisor` enum('usuario','ia') DEFAULT NULL,
  `contexto` varchar(60) DEFAULT NULL,
  `solicitud` text NOT NULL,
  `respuesta` text DEFAULT NULL,
  `informacion_clave` text DEFAULT NULL,
  `fecha_envio` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `modulos`
--

CREATE TABLE `modulos` (
  `id_modulo` int(11) NOT NULL,
  `nombre_modulo` varchar(100) NOT NULL,
  `descripcion` varchar(255) NOT NULL DEFAULT '',
  `status` int(11) NOT NULL DEFAULT 1,
  `tipo_modulo` enum('Seguridad','Negocio') NOT NULL,
  `ruta` varchar(100) NOT NULL DEFAULT '',
  `icono` varchar(50) NOT NULL DEFAULT 'fa-circle'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `notificaciones`
--

CREATE TABLE `notificaciones` (
  `id_notificaciones` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `titulo` varchar(80) NOT NULL,
  `descripcion_notificacion` varchar(400) NOT NULL,
  `enlace` varchar(100) NOT NULL,
  `alcance` varchar(50) NOT NULL,
  `fecha_notificacion` datetime(6) NOT NULL,
  `leido` int(11) NOT NULL DEFAULT 1,
  `tipo` varchar(50) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `permisos`
--

CREATE TABLE `permisos` (
  `id_permisos` int(11) NOT NULL,
  `nombre_permiso` varchar(100) NOT NULL,
  `tipo` enum('CRUD','Especial') NOT NULL DEFAULT 'Especial'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `permisos_usuario`
--

CREATE TABLE `permisos_usuario` (
  `id_permiso_usuario` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `id_modulo` int(11) NOT NULL,
  `id_permiso` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `respaldos`
--

CREATE TABLE `respaldos` (
  `id_respaldo` int(11) NOT NULL,
  `nombre_archivo` varchar(100) NOT NULL,
  `tipo_respaldo` varchar(50) NOT NULL,
  `ruta_almacenamiento` varchar(255) NOT NULL,
  `peso_kb` decimal(10,2) NOT NULL,
  `total_registros` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `fecha_creacion` datetime DEFAULT NULL,
  `tipo_bd` varchar(100) NOT NULL,
  `formato` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `respaldo_programado`
--

CREATE TABLE `respaldo_programado` (
  `id_programado` int(11) NOT NULL,
  `frecuencia` enum('semanal','quincenal','mensual','anual') NOT NULL,
  `base_datos` enum('negocio','seguridad','ambas') NOT NULL DEFAULT 'ambas',
  `formato` varchar(10) NOT NULL DEFAULT 'sql',
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `ultima_ejecucion` datetime DEFAULT NULL,
  `proxima_ejecucion` datetime DEFAULT NULL,
  `id_usuario` int(11) NOT NULL,
  `fecha_creacion` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `roles`
--

CREATE TABLE `roles` (
  `id_rol` int(11) NOT NULL,
  `nombre_rol` varchar(100) NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tokens`
--

CREATE TABLE `tokens` (
  `id_tokens` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `codigo` varchar(11) NOT NULL,
  `token` varchar(100) NOT NULL,
  `expira` datetime DEFAULT NULL,
  `usado` int(11) NOT NULL,
  `fecha_creacion` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
--


-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `id_usuario` int(11) NOT NULL,
  `id_cliente` varchar(11) DEFAULT NULL,
  `nombre_usuario` varchar(100) NOT NULL,
  `password_usuario` mediumtext NOT NULL,
  `email_usuario` varchar(100) NOT NULL,
  `email_verificado` int(11) NOT NULL,
  `id_rol_usuario` int(11) NOT NULL,
  `avatar` varchar(100) NOT NULL,
  `ultimo_acceso` datetime(6) DEFAULT NULL,
  `fecha_registro` datetime(6) DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `intentos_login` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `bloqueado_hasta` datetime DEFAULT NULL,
  `token_sesion` varchar(200) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
--


--
-- Disparadores `usuarios`
--
DELIMITER $$
CREATE TRIGGER `trg_auditoria_fallo_acceso` AFTER UPDATE ON `usuarios` FOR EACH ROW BEGIN

    -- Usamos password_usuario tal como aparece en tu estructura

    IF NEW.password_usuario <> OLD.password_usuario THEN

        INSERT INTO larence_seguridad.bitacoras (id_usuario, modulo, accion, descripcion, fecha_bitacora) 

        VALUES (OLD.id_usuario, 'Seguridad', 'Cambio de Clave', CONCAT('El usuario ', OLD.nombre_usuario, ' cambi├│ su contrase├▒a.'), NOW());

    END IF;

END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_proteger_admin` BEFORE DELETE ON `usuarios` FOR EACH ROW BEGIN

    IF OLD.id_usuario = 1 THEN

        SIGNAL SQLSTATE '45000'

        SET MESSAGE_TEXT = 'ERROR CR├ìTICO: No se puede eliminar el usuario administrador principal.';

    END IF;

END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_proteger_rol_admin` BEFORE UPDATE ON `usuarios` FOR EACH ROW BEGIN

    -- Si el usuario siendo editado es el ID 1 y est├ín intentando cambiar su rol

    IF OLD.id_usuario = 1 AND NEW.id_rol_usuario <> OLD.id_rol_usuario THEN

        SIGNAL SQLSTATE '45000' 

        SET MESSAGE_TEXT = 'ERROR: No est├í permitido modificar el rol del Administrador principal.';

    END IF;

END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_validar_pass_seguro` BEFORE INSERT ON `usuarios` FOR EACH ROW BEGIN

    IF LENGTH(NEW.password_usuario) < 8 THEN

        SIGNAL SQLSTATE '45000' 

        SET MESSAGE_TEXT = 'Seguridad: La contrase├▒a debe tener m├¡nimo 8 caracteres.';

    END IF;

END
$$
DELIMITER ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `accesos`
--
ALTER TABLE `accesos`
  ADD PRIMARY KEY (`id_accesos`),
  ADD KEY `id_rol` (`id_rol`),
  ADD KEY `id_modulo` (`id_modulo`),
  ADD KEY `id_permiso` (`id_permiso`);

--
-- Indices de la tabla `bitacoras`
--
ALTER TABLE `bitacoras`
  ADD PRIMARY KEY (`id_bitacora`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `conversaciones_ia`
--
ALTER TABLE `conversaciones_ia`
  ADD PRIMARY KEY (`id_conversacion`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `mensajes_ia`
--
ALTER TABLE `mensajes_ia`
  ADD PRIMARY KEY (`id_mensaje`),
  ADD KEY `idx_conversacion` (`id_conversacion`);

--
-- Indices de la tabla `modulos`
--
ALTER TABLE `modulos`
  ADD PRIMARY KEY (`id_modulo`);

--
-- Indices de la tabla `notificaciones`
--
ALTER TABLE `notificaciones`
  ADD PRIMARY KEY (`id_notificaciones`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `permisos`
--
ALTER TABLE `permisos`
  ADD PRIMARY KEY (`id_permisos`);

--
-- Indices de la tabla `permisos_usuario`
--
ALTER TABLE `permisos_usuario`
  ADD PRIMARY KEY (`id_permiso_usuario`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_modulo` (`id_modulo`),
  ADD KEY `id_permiso` (`id_permiso`);

--
-- Indices de la tabla `respaldos`
--
ALTER TABLE `respaldos`
  ADD PRIMARY KEY (`id_respaldo`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `respaldo_programado`
--
ALTER TABLE `respaldo_programado`
  ADD PRIMARY KEY (`id_programado`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id_rol`);

--
-- Indices de la tabla `tokens`
--
ALTER TABLE `tokens`
  ADD PRIMARY KEY (`id_tokens`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id_usuario`),
  ADD KEY `id_rol_usuario` (`id_rol_usuario`),
  ADD KEY `id_cliente` (`id_cliente`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `accesos`
--
ALTER TABLE `accesos`
  MODIFY `id_accesos` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2183;

--
-- AUTO_INCREMENT de la tabla `bitacoras`
--
ALTER TABLE `bitacoras`
  MODIFY `id_bitacora` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5525;

--
-- AUTO_INCREMENT de la tabla `conversaciones_ia`
--
ALTER TABLE `conversaciones_ia`
  MODIFY `id_conversacion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `mensajes_ia`
--
ALTER TABLE `mensajes_ia`
  MODIFY `id_mensaje` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=50;

--
-- AUTO_INCREMENT de la tabla `modulos`
--
ALTER TABLE `modulos`
  MODIFY `id_modulo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT de la tabla `notificaciones`
--
ALTER TABLE `notificaciones`
  MODIFY `id_notificaciones` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=216;

--
-- AUTO_INCREMENT de la tabla `permisos`
--
ALTER TABLE `permisos`
  MODIFY `id_permisos` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT de la tabla `permisos_usuario`
--
ALTER TABLE `permisos_usuario`
  MODIFY `id_permiso_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT de la tabla `respaldos`
--
ALTER TABLE `respaldos`
  MODIFY `id_respaldo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `respaldo_programado`
--
ALTER TABLE `respaldo_programado`
  MODIFY `id_programado` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `roles`
--
ALTER TABLE `roles`
  MODIFY `id_rol` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT de la tabla `tokens`
--
ALTER TABLE `tokens`
  MODIFY `id_tokens` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `accesos`
--
ALTER TABLE `accesos`
  ADD CONSTRAINT `accesos_ibfk_1` FOREIGN KEY (`id_rol`) REFERENCES `roles` (`id_rol`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `accesos_ibfk_2` FOREIGN KEY (`id_modulo`) REFERENCES `modulos` (`id_modulo`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `accesos_ibfk_3` FOREIGN KEY (`id_permiso`) REFERENCES `permisos` (`id_permisos`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `bitacoras`
--
ALTER TABLE `bitacoras`
  ADD CONSTRAINT `bitacoras_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `conversaciones_ia`
--
ALTER TABLE `conversaciones_ia`
  ADD CONSTRAINT `conversaciones_ia_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `mensajes_ia`
--
ALTER TABLE `mensajes_ia`
  ADD CONSTRAINT `mensajes_ia_ibfk_1` FOREIGN KEY (`id_conversacion`) REFERENCES `conversaciones_ia` (`id_conversacion`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `notificaciones`
--
ALTER TABLE `notificaciones`
  ADD CONSTRAINT `notificaciones_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `permisos_usuario`
--
ALTER TABLE `permisos_usuario`
  ADD CONSTRAINT `permisos_usuario_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `respaldos`
--
ALTER TABLE `respaldos`
  ADD CONSTRAINT `respaldos_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `respaldo_programado`
--
ALTER TABLE `respaldo_programado`
  ADD CONSTRAINT `respaldo_programado_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `tokens`
--
ALTER TABLE `tokens`
  ADD CONSTRAINT `tokens_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`id_rol_usuario`) REFERENCES `roles` (`id_rol`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
