"""
Loads kong.yml declarative configuration file from secrets to kong if DB-less mode is activated. If kong
provides an in-house method of loading without restarting containers in docker and kubernetes then this should be
removed
"""
import logging.config
import os
from pathlib import Path
import time
import base64
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from settings import LOGGING_CONFIG
from kubernetes import client, config
import json
import datetime

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
logging.config.dictConfig(LOGGING_CONFIG)
logger = logging.getLogger("gg-entrypoint")

GLUU_GATEWAY_NAMESPACE = os.environ.get("GLUU_GATEWAY_NAMESPACE", "gluu-gateway")
# In helm deployments
POD_NAMESPACE = os.environ.get("POD_NAMESPACE", "")
if POD_NAMESPACE:
    GLUU_GATEWAY_NAMESPACE = POD_NAMESPACE

GLUU_GATEWAY_KONG_CONF_SECRET_NAME = os.environ.get("GLUU_GATEWAY_KONG_CONF_SECRET_NAME", "kong-config")
KONG_DATABASE = os.environ.get("KONG_DATABASE", "off")
GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG = os.environ.get("GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG", "/etc/gg-kong.yml")
KONG_ADMIN_LISTEN = os.environ.get("KONG_ADMIN_LISTEN", "127.0.0.1:8444")
KONG_DECLARATIVE_CONFIG = os.environ.get("KONG_DECLARATIVE_CONFIG", "")


def load_kubernetes_config():
    """
    Loads kubernetes configuration in cluster or from file to be able to interact with kubernetes api
    :return:
    """
    config_loaded = False
    try:
        config.load_incluster_config()
        config_loaded = True
    except config.config_exception.ConfigException:
        logger.debug("Unable to load in-cluster configuration; trying to load from Kube config file")
        try:
            config.load_kube_config()
            config_loaded = True
        except (IOError, config.config_exception.ConfigException) as exc:
            logger.debug("Unable to load Kube config; reason={}".format(exc))

    if not config_loaded:
        logger.error("Unable to load in-cluster or Kube config")
        raise SystemExit(1)


class Kubernetes(object):
    def __init__(self):
        load_kubernetes_config()
        self.core_cli = client.CoreV1Api()
        self.core_cli.api_client.configuration.assert_hostname = False

    @staticmethod
    def check_read_error_and_response(starting_time, resp, name):
        """
        Checks existence of kong deceleration conf file in secret and times-out after 5 mins waiting for secret
        to be ready.
        :param starting_time:
        :param resp:
        :param name:
        :return:
        """
        load_kubernetes_config()
        end_time = time.time()
        running_time = end_time - starting_time

        if resp.status == 404:
            logger.error("Secret {} does not exist, has been removed or might be set to defaults. "
                         "Please create secret containing kong.yml declarative_config"
                         "inside kongs namespace. Add the following envs to kong deployment:\n"
                         "---\n"
                         "GLUU_GATEWAY_KONG_CONF_SECRET_NAME:<my-kongs-declaration-file-secret-name>\n"
                         "GLUU_GATEWAY_NAMESPACE:<kongs-namespace>"
                         "or omit and use defaults : "
                         "GLUU_GATEWAY_KONG_CONF_SECRET_NAME:kong-config\n"
                         "GLUU_GATEWAY_NAMESPACE:gg-gluu"
                         "---\n"
                         "Run the following command to create secret:\n"
                         "kubectl create secret generic <my-kongs-declaration-file-secret-name> "
                         "-n <kongs-namespace> --from-file=kong.yml".format(name))
            logger.error("Timeout in : {}".format(str(round(320 - running_time)) + " secs"))
            time.sleep(20)
            if running_time > 300:
                logger.error("Gluu-Gateway-Timeout. Secret was not found after time limit")
                raise SystemExit(1)
            return True
        else:
            # The kubernetes object has been found"
            return False

    def read_namespaced_secret(self, name, namespace="kong-config"):
        """
        Read secret with name in namespace
        :param name:
        :param namespace:
        :return:
        """
        load_kubernetes_config()
        starting_time = time.time()
        response = True
        status_not_found = False
        while response:
            try:
                secret = self.core_cli.read_namespaced_secret(name=name, namespace=namespace)
                logger.debug('Reading secret {}'.format(name))
                # If secret is found after 404
                if status_not_found:
                    logger.info("Secret {} found".format(name))
                return secret
            except client.rest.ApiException as e:
                status_not_found = True
                response = self.check_read_error_and_response(starting_time, e, name)


def find_admin_ip_port():
    """
    Returns admin ip:port from KONG_ADMIN_LISTEN env
    :return:
    """
    admin_ip_port_list = KONG_ADMIN_LISTEN.split(" ")
    admin_ip_port = None
    for item in admin_ip_port_list:
        if ":" in item:
            admin_ip_port = item
    return admin_ip_port


def get_kong_declarative_config_from_file():
    """
    Get kong declarative config settings from file at location GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG
    :return:
    """
    filename = Path(GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG)
    try:
        with open(filename) as f:
            kong_declarative_config = json.load(f)
        return kong_declarative_config
    except FileNotFoundError:
        logger.info("Kong declarative config file was not found at {}".format(GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG))
        # Initial start so get kong from secret and dump to file
        kong_declarative_config_from_secret = get_kong_declarative_config_from_secret()
        dump_kong_declarative_config(kong_declarative_config_from_secret)
        return kong_declarative_config_from_secret


def load_kong_declarative_config(kong_declarative_config_from_secret):
    """
    Get kong declarative config settings from secret kong_declarative_config_from_secret
    :param kong_declarative_config_from_secret:
    :return:
    """
    admin_ip_port = find_admin_ip_port()
    response = requests.post("https://" + admin_ip_port + "/config",
                             json=kong_declarative_config_from_secret, verify=False)
    if response.status_code == 201:
        logger.info("Status-code: " + str(response.status_code) +
                    " -  Kong declarative config file successfully loaded")
        logger.debug("Response of loading Kong declarative config file can be found at /etc/gg_kong_load.log")
        json_response = response.json()
        datetime_object = str(datetime.datetime.now())
        with open(Path("/etc/gg_kong_load.log"), "a+") as file:
            file.write(datetime_object + " - " + str(json_response))
            file.write("\n--------------------------------------------\n")
    else:
        logger.error(response.content)


def dump_kong_declarative_config(settings):
    """
    Write kong declarative config (settings) out to  kong.yml at location GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG
    :param settings:
    :return:
    """
    try:
        with open(Path(GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG), 'w+') as file:
            logging.debug("Dumping kong declarative config file at {} ".format(GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG))
            json.dump(settings, file, indent=2)
    except OSError as e:
        logger.error(e)
        logger.info("It looks like you don't have permission to write at {} or you "
                    "may have mounted kongs declarative config file at {}. "
                    "Please un-mount kong declarative config file as it will be pulled directly"
                    " from secrets".format(GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG, GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG))


def get_kong_declarative_config_from_secret():
    """
    Get kong declarative config settings from secret GLUU_GATEWAY_KONG_CONF_SECRET_NAME
    in namespace GLUU_GATEWAY_NAMESPACE
    :return:
    """
    kong_conf_filename = GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG.lstrip("/etc/")
    kubernetes = Kubernetes()
    kong_declarative_config_from_secret = kubernetes.read_namespaced_secret(name=GLUU_GATEWAY_KONG_CONF_SECRET_NAME,
                                                                            namespace=GLUU_GATEWAY_NAMESPACE)
    kong_declarative_config_from_secret_encrypted = kong_declarative_config_from_secret.data[kong_conf_filename]
    kong_declarative_config_from_secret_decrypted = base64.b64decode(
        kong_declarative_config_from_secret_encrypted).decode("utf-8")
    kong_declarative_config_from_secret_json = json.loads(kong_declarative_config_from_secret_decrypted)
    return kong_declarative_config_from_secret_json


def main():
    if KONG_DATABASE == "off":
        while True:
            if KONG_DECLARATIVE_CONFIG:
                logger.error("KONG_DECLARATIVE_CONFIG env has been set. Please unset it and use "
                            "GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG instead as the kong declarative config file will be"
                            " loaded automatically from secrets given GLUU_GATEWAY_NAMESPACE "
                            "and GLUU_GATEWAY_KONG_CONF_SECRET_NAME are set correctly")
                time.sleep(30)
            else:
                break

        kong_declarative_config_from_file = get_kong_declarative_config_from_file()
        load_kong_declarative_config(kong_declarative_config_from_file)
        while True:
            kong_declarative_config_from_file = get_kong_declarative_config_from_file()
            kong_declarative_config_from_secret = get_kong_declarative_config_from_secret()
            # Check if conf in secret has changed by comparing to file in container
            if kong_declarative_config_from_secret != kong_declarative_config_from_file:
                load_kong_declarative_config(kong_declarative_config_from_secret)
                dump_kong_declarative_config(kong_declarative_config_from_secret)
            gluu_gateway_kong_dbless_conf_interval_check = int(
                os.environ.get("GLUU_GATEWAY_KONG_DBLESS_CONF_INTERVAL_CHECK", 60))
            time.sleep(gluu_gateway_kong_dbless_conf_interval_check)


if __name__ == "__main__":
    main()
