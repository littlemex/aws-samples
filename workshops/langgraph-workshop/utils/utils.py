import logging
import os
import pprint

import boto3


def set_logger(log_level: str = "INFO") -> object:
    log_level = os.environ.get("LOG_LEVEL", log_level).strip().upper()
    logging.basicConfig(format="[%(asctime)s] p%(process)s {%(filename)s:%(lineno)d} %(levelname)s - %(message)s")
    logger = logging.getLogger(__name__)
    logger.setLevel(log_level)
    return logger


logger = set_logger()


def set_pretty_printer():
    return pprint.PrettyPrinter(indent=2, width=100)


def get_tavily_api(key: str, region_name: str) -> str:
    # 現在のディレクトリから見た.envファイルのパスを確認
    env_paths = ["../.env", ".env"]
    env_file_exists = False
    
    for path in env_paths:
        if os.path.isfile(path):
            env_file_exists = True
            break
    
    if not env_file_exists:
        raise Exception('Local environment variable file .env not existing! Please create with the command: cp env.tmp .env')
    
    tavily_api_prefix = "tvly-"
    # os.environ.get()を使用してKeyErrorを回避
    env_value = os.environ.get(key)
    
    # 環境変数が存在しないか、正しいプレフィックスで始まらない場合
    if env_value is None or not env_value.startswith(tavily_api_prefix):
        if env_value is None:
            logger.info(f"{key} not found in environment variables. Trying from AWS Secrets Manager.")
        else:
            logger.info(f"{key} value not correctly set in the .env file, expected a key to start with \"{tavily_api_prefix}\" but got it starting with \"{env_value[:5]}\". Trying from AWS Secrets Manager.")
        
        session = boto3.session.Session()
        secrets_manager = session.client(service_name="secretsmanager", region_name=region_name)
        try:
            secret_value = secrets_manager.get_secret_value(SecretId=key)
        except Exception as e:
            logger.error(f"{key} secret couldn't be retrieved correctly from AWS Secrets Manager either! Received error message:\n{e}")
            # 環境変数が存在する場合は、それを使用する（プレフィックスが正しくなくても）
            if env_value is not None:
                logger.warning(f"Falling back to environment variable value for {key} despite incorrect prefix.")
                return env_value
            raise e

        logger.info(f"{key} variable correctly retrieved from the AWS Secret Manager.")
        secret_string = secret_value["SecretString"]
        secret = eval(secret_string, {"__builtins__": {}}, {})[key]
        if not secret:
            raise Exception(f"{key} value not correctly set in the AWS Secrets Manager.")
        os.environ[key] = secret
    else:
        logger.info(f"{key} variable correctly retrieved from the .env file.")
        secret = env_value

    return secret


def visualize_graph(agent):
    """
    LangGraphのグラフを可視化する関数
    
    Parameters:
    -----------
    agent : Agent
        可視化するグラフを持つAgentオブジェクト
    
    Returns:
    --------
    None
        グラフを表示するか、エラーが発生した場合はASCII表示を行います
    """
    from IPython.display import Image, display
    
    try:
        # Mermaid PNGでグラフを可視化
        display(Image(agent.graph.get_graph().draw_mermaid_png()))
    except Exception as e:
        # エラーメッセージを表示
        print(f"グラフの可視化に失敗しました: {str(e)}")
        print("代わりにASCII表示を使用します:\n")
        # 代替としてASCII表示を使用
        print(agent.graph.get_graph().draw_ascii())
