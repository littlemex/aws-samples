# Welcome to your CDK TypeScript project!

This is a blank project for TypeScript development with CDK.

The `cdk.json` file tells the CDK Toolkit how to execute your app.

## Useful commands

 * `npm run build`   compile typescript to js
 * `npm run watch`   watch for changes and compile
 * `npm run test`    perform the jest unit tests
 * `cdk deploy`      deploy this stack to your default AWS account/region
 * `cdk diff`        compare deployed stack with current state
 * `cdk synth`       emits the synthesized CloudFormation template
 
## 参考  
- [goの使用についての公式ページ](https://docs.aws.amazon.com/ja_jp/lambda/latest/dg/lambda-golang.html)  
- [aws-go-lambdaのclassmethodページ](https://dev.classmethod.jp/articles/aws-lambda-go/)  
- [CDKでGolangのLambdaを作成](https://zenn.dev/panyoriokome/scraps/a8576a65b6ca15)  (これはaws-go-lambda使わないパターン)  

## 導入メモ  
- aws-lambda-goとcoreバージョンがずれていると出るエラー  
  - https://shootacean.com/entry/2019/10/29/aws-cdk-argument-of-type-this-is-not-assignable-to-parameter-of-type-construct-error-handling
  - バージョンを合わせる rm -rf node_modules && npm i  
- lambdaディレクトリでgo mod init してからgo getでlambdaライブラリを入れる  
- ローカルテスト  
  - cdk synth --no-staging > template.yaml  
  - sam local invoke handlerE1533BD5 --no-event を叩いて"Hello!"が出たらおけ  
